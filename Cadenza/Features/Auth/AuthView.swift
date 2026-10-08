import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @AppStorage("languageChosen") private var languageChosen: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = ""

    @State private var isSignUp = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorText: String?
    @State private var busy = false
    @FocusState private var focused: Field?

    private enum Field: Hashable { case name, email, password }

    // MARK: - Localized strings

    private var headingSignUp: String { localized("계정을\n만들어보세요", "Create your\nAccount", "Konto\nerstellen") }
    private var headingSignIn: String { localized("다시\n만났네요", "Sign in to your\nAccount", "Wieder\nda?") }
    private var subtitleSignUp: String { localized("음악 커리어의 여정을 함께 기록해요.", "Start recording your music career.", "Dokumentiere deine Musikkarriere.") }
    private var subtitleSignIn: String { localized("다시 돌아오셨군요, 반갑습니다.", "Welcome back.", "Willkommen zurück.") }
    private var tabSignUp: String { localized("계정 만들기", "Sign Up", "Registrieren") }
    private var tabSignIn: String { localized("로그인", "Log In", "Anmelden") }
    private var placeholderName: String { localized("이름", "Name", "Name") }
    private var placeholderEmail: String { localized("이메일", "Email", "E-Mail") }
    private var placeholderPasswordNew: String { localized("비밀번호 (6자 이상)", "Password (6+ chars)", "Passwort (mind. 6)") }
    private var placeholderPassword: String { localized("비밀번호", "Password", "Passwort") }
    private var ctaSignUp: String { localized("시작하기", "Get Started", "Loslegen") }
    private var ctaSignIn: String { localized("로그인", "Log In", "Anmelden") }
    private var dividerOr: String { localized("또는", "or", "oder") }
    private var forgotPassword: String { localized("비밀번호를 잊으셨나요?", "Forgot password?", "Passwort vergessen?") }
    private var googleLabel: String { localized("Google로 계속하기", "Continue with Google", "Mit Google fortfahren") }
    private var appleLabel: String { localized("Apple로 계속하기", "Continue with Apple", "Mit Apple fortfahren") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Back button ───────────────────────────────────
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { languageChosen = false }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // ── Heading ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text(isSignUp ? headingSignUp : headingSignIn)
                        .font(.system(size: 30, weight: .bold))
                        .lineSpacing(3)
                        .animation(.none, value: isSignUp)

                    Text(isSignUp ? subtitleSignUp : subtitleSignIn)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .animation(.none, value: isSignUp)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 36)

                // ── Mode tabs ─────────────────────────────────────
                HStack(spacing: 0) {
                    modeTab(label: tabSignUp, active: isSignUp) {
                        withAnimation(.easeInOut(duration: 0.22)) { isSignUp = true }
                    }
                    modeTab(label: tabSignIn, active: !isSignUp) {
                        withAnimation(.easeInOut(duration: 0.22)) { isSignUp = false }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)

                // ── Fields card ───────────────────────────────────
                VStack(spacing: 0) {
                    if isSignUp {
                        fieldRow(icon: "person", placeholder: placeholderName,
                                 text: $name, field: .name,
                                 contentType: .name)
                        rowDivider()
                    }

                    fieldRow(icon: "envelope", placeholder: placeholderEmail,
                             text: $email, field: .email,
                             contentType: .emailAddress,
                             keyboard: .emailAddress,
                             capitalization: .never)
                    rowDivider()

                    passwordRow()
                }
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 22)
                .animation(.easeInOut(duration: 0.2), value: isSignUp)

                // ── Forgot password ───────────────────────────────
                if !isSignUp {
                    HStack {
                        Spacer()
                        Button(forgotPassword) { }
                            .font(.footnote)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .transition(.opacity)
                }

                // ── Error ─────────────────────────────────────────
                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // ── Primary CTA ───────────────────────────────────
                Button(action: submit) {
                    ZStack {
                        if busy { ProgressView().tint(.white).foregroundStyle(.white) }
                        else {
                            Text(isSignUp ? ctaSignUp : ctaSignIn)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                }
                .background(
                    isValid ? Color.accentColor : Color.accentColor.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
                .disabled(busy || !isValid)
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .animation(.easeInOut(duration: 0.15), value: isValid)

                // ── Divider ───────────────────────────────────────
                HStack(spacing: 12) {
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                    Text(dividerOr).font(.footnote).foregroundStyle(.secondary)
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)

                // ── Social buttons ────────────────────────────────
                VStack(spacing: 12) {
                    socialButton(
                        label: googleLabel,
                        icon: { googleIcon },
                        background: Color(.systemBackground),
                        foreground: Color(.label),
                        action: { signInWithSocialProvider(.google) }
                    )
                    socialButton(
                        label: appleLabel,
                        icon: {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 16, weight: .medium))
                        },
                        background: Color(.label),
                        foreground: Color(.systemBackground),
                        action: { signInWithSocialProvider(.apple) }
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)

                Spacer(minLength: 52)
            }
            .adaptiveContentWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
        .id(appLanguage) // 언어 변경 시 뷰 강제 재생성
    }

    // MARK: - Google icon

    private var googleIcon: some View {
        Text("G")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(red: 0.26, green: 0.52, blue: 0.96),
                             Color(red: 0.92, green: 0.26, blue: 0.21)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Mode tab

    private func modeTab(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(active ? .semibold : .regular)
                    .foregroundStyle(active ? Color.accentColor : .secondary)
                Capsule()
                    .fill(active ? Color.accentColor : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    // MARK: - Field rows

    @ViewBuilder
    private func fieldRow(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        contentType: UITextContentType,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .words
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(focused == field ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: 18)
                .padding(.leading, 16)
                .animation(.easeInOut(duration: 0.15), value: focused == field)

            TextField(placeholder, text: text)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .focused($focused, equals: field)
                .font(.body)
                .padding(.vertical, 16)
                .padding(.trailing, 16)
        }
    }

    @ViewBuilder
    private func passwordRow() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock")
                .font(.system(size: 14))
                .foregroundStyle(focused == .password ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: 18)
                .padding(.leading, 16)
                .animation(.easeInOut(duration: 0.15), value: focused == .password)

            Group {
                if showPassword {
                    TextField(isSignUp ? placeholderPasswordNew : placeholderPassword,
                              text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(isSignUp ? placeholderPasswordNew : placeholderPassword,
                                text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
            }
            .focused($focused, equals: .password)
            .font(.body)
            .padding(.vertical, 16)

            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
    }

    private func rowDivider() -> some View {
        Divider().padding(.leading, 44)
    }

    // MARK: - Social button

    private func socialButton<Icon: View>(
        label: String,
        icon: () -> Icon,
        background: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                Text(label).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    // MARK: - Logic

    private var isValid: Bool {
        let emailOK = email.contains("@") && email.count >= 5
        let pwOK = password.count >= 6
        let nameOK = !isSignUp || name.trimmingCharacters(in: .whitespaces).count >= 2
        return emailOK && pwOK && nameOK
    }

    private func submit() {
        focused = nil
        busy = true
        errorText = nil
        Task {
            do {
                if isSignUp { try await session.signUp(name: name, email: email, password: password) }
                else        { try await session.signIn(email: email, password: password) }
            } catch {
                errorText = error.localizedDescription
            }
            busy = false
        }
    }

    private enum SocialProvider {
        case google
        case apple
    }

    private func signInWithSocialProvider(_ provider: SocialProvider) {
        focused = nil
        busy = true
        errorText = nil

        Task {
            do {
                switch provider {
                case .google:
                    try await session.signInWithGoogle()
                case .apple:
                    try await session.signInWithApple()
                }
            } catch let error as ASWebAuthenticationSessionError
                where error.code == .canceledLogin {
                // Closing the provider sheet is an intentional cancellation.
            } catch {
                errorText = error.localizedDescription
            }
            busy = false
        }
    }
}
