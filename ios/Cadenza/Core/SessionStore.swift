import AuthenticationServices
import Foundation
import Supabase

@MainActor
@Observable
final class SessionStore {
    let client: SupabaseClient
    let repo: Repository
    let connections: ConnectionStore

    var session: Session?
    var isBootstrapping = true
    var isPasswordRecovery = false
    @ObservationIgnored private var appleSignInCoordinator: AppleSignInCoordinator?
    var profile: Profile?
    var profileError: String?
    /// Changes only after an authenticated session has been validated and its
    /// profile bootstrap has finished. Data screens use this instead of racing
    /// the raw auth callback.
    var authenticatedDataRevision = 0

    // MARK: - Push notifications
    /// 알림 탭으로 이동 요청 카운터 (RootTabView 에서 onChange 감지)
    var openNotificationsRevision = 0
    @ObservationIgnored private var pushToken: String?

    init() {
        #if DEBUG
        let authStorage: any AuthLocalStorage = UserDefaultsLocalStorage()
        #else
        let authStorage: any AuthLocalStorage = KeychainLocalStorage()
        #endif
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: .init(
                auth: .init(
                    storage: authStorage,
                    redirectToURL: AppConfig.authCallbackURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        repo = Repository(client: client)
        let repository = repo
        connections = ConnectionStore(fetch: { try await repository.connectionRecords(userId: $0) },
                                      change: { try await repository.transitionConnection(with: $0, action: $1) })
        Task { await observeAuth() }

        // PushNotificationManager 콜백 연결
        PushNotificationManager.shared.onTokenRegistered = { [weak self] token in
            Task { [weak self] in await self?.registerPushToken(token) }
        }
        PushNotificationManager.shared.onNotificationTap = { [weak self] in
            self?.openNotificationsRevision &+= 1
        }
    }

    var currentUserID: UUID? { session?.user.id }
    var needsOnboarding: Bool {
        guard let p = profile else { return false }
        return !p.onboardingComplete
    }

    // MARK: - Auth observation

    private func observeAuth() async {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let email = env["CADENZA_DEV_EMAIL"], let pw = env["CADENZA_DEV_PASSWORD"] {
            try? await client.auth.signIn(email: email, password: pw)
        }
        #endif
        for await change in client.auth.authStateChanges {
            if change.event == .passwordRecovery {
                isPasswordRecovery = true
            } else if change.event == .userUpdated || change.event == .signedOut {
                isPasswordRecovery = false
            }
            await applyAuthChange(change.session)
        }
    }

    // Called from .onOpenURL — processes cadenza://auth-callback deep links.
    nonisolated func handleURL(_ url: URL) {
        client.auth.handle(url)
    }

    func refreshProfile() async {
        guard let uid = currentUserID else { return }
        do {
            let validSession = try await ensureAuthenticatedSession()
            guard validSession.user.id == uid else { return }
            let loadedProfile = try await repo.myProfile(id: uid)
            guard currentUserID == uid else { return }
            profile = loadedProfile
            profileError = nil
        } catch {
            guard currentUserID == uid else { return }
            profileError = error.localizedDescription
        }
    }

    /// Supabase can emit a stored session before an expired token has finished
    /// refreshing. Awaiting `auth.session` gives repositories a valid token and
    /// makes the authenticated-data boundary explicit.
    @discardableResult
    func ensureAuthenticatedSession() async throws -> Session {
        let validSession = try await client.auth.session
        if session?.user.id == validSession.user.id {
            session = validSession
        }
        return validSession
    }

    private func applyAuthChange(_ candidate: Session?) async {
        #if DEBUG
        print("[Auth] applyAuthChange event — session: \(candidate?.user.email ?? "nil")")
        #endif
        guard let candidate else {
            // 로그아웃: 저장된 토큰 서버에서 제거
            if let token = pushToken {
                try? await repo.unregisterPushToken(token)
                pushToken = nil
            }
            session = nil
            connections.reset(for: nil)
            profile = nil
            profileError = nil
            authenticatedDataRevision += 1
            isBootstrapping = false
            return
        }

        do {
            let validSession = try await client.auth.session
            guard validSession.user.id == candidate.user.id else { return }

            let userChanged = session?.user.id != validSession.user.id
            session = validSession
            if userChanged {
                profile = nil
                connections.reset(for: validSession.user.id)
                // 다른 계정으로 전환 시 이전 토큰 재등록
                if let token = pushToken {
                    try? await repo.registerPushToken(token, userId: validSession.user.id)
                }
            }

            do {
                profile = try await repo.myProfile(id: validSession.user.id)
                profileError = nil
            } catch {
                profileError = error.localizedDescription
            }
        } catch {
            #if DEBUG
            print("[Auth] applyAuthChange catch: \(error)")
            #endif
            session = nil
            connections.reset(for: nil)
            profile = nil
            profileError = error.localizedDescription
        }

        authenticatedDataRevision += 1
        isBootstrapping = false
    }

    // MARK: - Push token

    func registerPushToken(_ token: String) async {
        pushToken = token
        guard let uid = currentUserID else { return }
        try? await repo.registerPushToken(token, userId: uid)
    }

    func navigateToNotificationsTab() {
        openNotificationsRevision &+= 1
    }

    // MARK: - Auth actions

    func signUp(name: String, email: String, password: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["real_name": .string(name)]
        )
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signInWithGoogle() async throws {
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: AppConfig.authCallbackURL
        )
    }

    func signInWithApple() async throws {
        let nonce = try makeRandomNonce()
        let hashedNonce = sha256Hex(nonce)

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let coordinator = AppleSignInCoordinator()
        appleSignInCoordinator = coordinator
        defer { appleSignInCoordinator = nil }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()

        let credential = try await coordinator.requestCredential()

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw ASAuthorizationError(.invalidResponse)
        }

        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: AppConfig.authCallbackURL)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
        isPasswordRecovery = false
    }

    func signOut() async {
        if let token = pushToken {
            try? await repo.unregisterPushToken(token)
            pushToken = nil
        }
        try? await client.auth.signOut()
        session = nil
        connections.reset(for: nil)
        profile = nil
        profileError = nil
        authenticatedDataRevision += 1
    }
}
