import SwiftUI

/// A two-state action button for sending or cancelling an outgoing connection request.
struct ConnectionRequestButton: View {
    let isRequested: Bool
    let isLoading: Bool
    var compact = false
    let action: () -> Void

    private var title: String {
        isRequested
            ? localized("요청됨", "Requested", "Angefragt")
            : localized("연결", "Connect", "Vernetzen")
    }

    private var hint: String {
        isRequested
            ? localized("연결 요청 취소", "Cancel connection request", "Verbindungsanfrage zurückziehen")
            : localized("연결 요청 보내기", "Send connection request", "Verbindungsanfrage senden")
    }

    private var foregroundColor: Color {
        isRequested ? Color.accentColor : .white
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foregroundColor)
                }

                Text(title)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, compact ? 10 : 14)
            .frame(height: compact ? 30 : 36)
            .background {
                Capsule()
                    .fill(isRequested ? Color("BrandSurface") : Color.accentColor)
            }
            .overlay {
                if isRequested {
                    Capsule()
                        .stroke(Color.accentColor.opacity(0.32), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(ConnectionRequestPressStyle())
        .disabled(isLoading)
        .frame(minHeight: 44)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
        .accessibilityValue(isRequested
            ? localized("요청을 보냄", "Request sent", "Anfrage gesendet")
            : localized("미연결", "Not connected", "Nicht verbunden"))
        .animation(.easeInOut(duration: 0.18), value: isRequested)
    }
}

private struct ConnectionRequestPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
