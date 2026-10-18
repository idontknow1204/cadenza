import SwiftUI

struct ForgotPasswordSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var busy = false
    @State private var sent = false
    @State private var errorText: String?
    @FocusState private var focused: Bool

    private var title: String { localized("비밀번호 재설정", "Reset Password", "Passwort zurücksetzen") }
    private var subtitle: String {
        localized(
            "가입한 이메일을 입력하면 재설정 링크를 보내드려요.",
            "Enter your email and we'll send you a reset link.",
            "Gib deine E-Mail ein und wir senden dir einen Link."
        )
    }
    private var sentTitle: String { localized("이메일을 확인하세요", "Check your email", "E-Mail prüfen") }
    private var sentBody: String {
        localized(
            "재설정 링크를 \(email)로 보냈어요. 링크를 탭하면 앱이 열리고 새 비밀번호를 설정할 수 있어요.",
            "A reset link was sent to \(email). Tap it to open the app and set a new password.",
            "Ein Link wurde an \(email) gesendet. Tippe darauf, um die App zu öffnen."
        )
    }
    private var ctaLabel: String { localized("링크 보내기", "Send Link", "Link senden") }
    private var closeLabel: String { localized("닫기", "Close", "Schließen") }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if sent {
                    sentView
                } else {
                    inputView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeLabel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Input view

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2.bold())
                .padding(.bottom, 8)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 28)

            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .font(.system(size: 14))
                    .foregroundStyle(focused ? Color.accentColor : Color.secondary.opacity(0.6))
                    .frame(width: 18)
                    .padding(.leading, 16)

                TextField(localized("이메일", "Email", "E-Mail"), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .font(.body)
                    .padding(.vertical, 16)
                    .padding(.trailing, 16)
            }
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14))
            .padding(.bottom, 12)

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.bottom, 12)
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
            .animation(.easeInOut(duration: 0.15), value: isValid)
        }
    }

    // MARK: - Sent view

    private var sentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "envelope.badge.checkmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 20)

            Text(sentTitle)
                .font(.title2.bold())
                .padding(.bottom, 8)
            Text(sentBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .padding(.bottom, 28)

            Button(closeLabel) { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Logic

    private var isValid: Bool { email.contains("@") && email.count >= 5 }

    private func submit() {
        focused = false
        busy = true
        errorText = nil
        Task {
            do {
                try await session.resetPassword(email: email)
                withAnimation { sent = true }
            } catch {
                errorText = error.localizedDescription
            }
            busy = false
        }
    }
}
