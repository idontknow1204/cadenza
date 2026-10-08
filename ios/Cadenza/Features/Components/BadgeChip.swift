import SwiftUI

/// Verification badge: 대기(회색) → 기관검증(초록).
struct BadgeChip: View {
    let status: VerificationStatus

    private var color: Color {
        status == .institutionVerified ? .green : .gray
    }

    private var iconName: String {
        status == .institutionVerified ? "checkmark.seal.fill" : "clock"
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
            Text(LocalizedStringKey(status.labelKey))
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}

/// Icon + label for an activity type.
struct ActivityTypeLabel: View {
    let type: ActivityType
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: type.symbol)
            Text(LocalizedStringKey(type.labelKey))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
