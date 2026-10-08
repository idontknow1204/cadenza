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
    var profile: Profile?
    var profileError: String?
    /// Changes only after an authenticated session has been validated and its
    /// profile bootstrap has finished. Data screens use this instead of racing
    /// the raw auth callback.
    var authenticatedDataRevision = 0

    init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: .init(
                auth: .init(redirectToURL: AppConfig.authCallbackURL)
            )
        )
        repo = Repository(client: client)
        let repository = repo
        connections = ConnectionStore(fetch: { try await repository.connectionRecords(userId: $0) },
                                      change: { try await repository.transitionConnection(with: $0, action: $1) })
        Task { await observeAuth() }
    }

    var currentUserID: UUID? { session?.user.id }
    var needsOnboarding: Bool {
        guard let p = profile else { return false }
        return !p.onboardingComplete
    }

    private func observeAuth() async {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let email = env["CADENZA_DEV_EMAIL"], let pw = env["CADENZA_DEV_PASSWORD"] {
            try? await client.auth.signIn(email: email, password: pw)
        }
        #endif
        for await change in client.auth.authStateChanges {
            await applyAuthChange(change.session)
        }
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
        guard let candidate else {
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
            }

            do {
                profile = try await repo.myProfile(id: validSession.user.id)
                profileError = nil
            } catch {
                profileError = error.localizedDescription
            }
        } catch {
            session = nil
            connections.reset(for: nil)
            profile = nil
            profileError = error.localizedDescription
        }

        authenticatedDataRevision += 1
        isBootstrapping = false
    }

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
        try await client.auth.signInWithOAuth(
            provider: .apple,
            redirectTo: AppConfig.authCallbackURL
        )
    }

    func signOut() async {
        try? await client.auth.signOut()
        session = nil
        connections.reset(for: nil)
        profile = nil
        profileError = nil
        authenticatedDataRevision += 1
    }
}
