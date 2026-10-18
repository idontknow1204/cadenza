import SwiftUI

struct ResetPasswordView: View {
    @Environment(SessionStore.self) private var session

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var busy = false
    @State private var errorText: String?
    @FocusState private var focused: Field?

    private enum Field: Hashable { case password, confirm }

    private var title: String { localized("새 비밀번호 설정", "Set New Password", "Neues Passwort") }
    private var subtitle: String {
        localized(
            "새 비밀번호를 입력해 주세요.",
            "Enter your new password below.",
            "Gib dein neues Passwort ein."
        )
    }
    private var ctaLabel: String { localized("비밀번호 변경", "Change Password", "Passwort ändern") }
    private var mismatch: String {
        localized("비밀번호가 일치하지 않아요.", "Passwords don't match.", "Passwörter stimmen nicht überein.")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 40)

                VStack(spacing: 0) {
                    passwordField(
                        placeholder: localized("새 비밀번호 (6자 이상)", "New password (6+ chars)", "Neues Passwort (mind. 6)"),
                        text: $password,
                        field: .password,
                        contentType: .newPassword
                    )
                    Divider().padding(.leading, 44)
                    passwordField(
                        placeholder: localized("비밀번호 확인", "Confirm password", "Passwort bestätigen"),
                        text: $confirmPassword,
                        field: .confirm,
                        contentType: .newPassword
                    )
                }
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 22)

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button(action: submit) {
                    ZStack {
                        if busy { ProgressView().tint(.white) }
                        else {
                            Text(ctaLabel)
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

                Spacer(minLength: 40)
            }
            .adaptiveContentWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
    }

    // MARK: - Password row

    @ViewBuilder
    private func passwordField(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        contentType: UITextContentType
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock")
                .font(.system(size: 14))
                .foregroundStyle(focused == field ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: 18)
                .padding(.leading, 16)
                .animation(.easeInOut(duration: 0.15), value: focused == field)

            Group {
                if showPassword {
                    TextField(placeholder, text: text)
                        .textContentType(contentType)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(placeholder, text: text)
                        .textContentType(contentType)
                }
            }
            .focused($focused, equals: field)
            .font(.body)
            .padding(.vertical, 16)

            if field == .password {
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            } else {
                Spacer().frame(width: 0).padding(.trailing, 16)
            }
        }
    }

    // MARK: - Logic

    private var isValid: Bool {
        password.count >= 6 && confirmPassword.count >= 6
    }

    private func submit() {
        guard password == confirmPassword else {
            withAnimation { errorText = mismatch }
            return
        }
        focused = nil
        busy = true
        errorText = nil
        Task {
            do {
                try await session.updatePassword(password)
            } catch {
                errorText = error.localizedDescription
            }
            busy = false
        }
    }
}
