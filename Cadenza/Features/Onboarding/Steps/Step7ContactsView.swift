import SwiftUI

/// Contact-based friend discovery. MVP: opt-in UI only — no actual contacts
/// access (that requires device entitlements + GDPR UX, pushed to M2).
struct Step7ContactsView: View {
    @Bindable var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.wave.2")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentColor)
                        Text("onboarding.step7.title").font(.largeTitle.bold())
                        Text("onboarding.step7.desc")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // Placeholder — actual contacts access comes in M2
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("onboarding.step7.comingsoon")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }
                .padding(.horizontal, 24)
            }
            Spacer(minLength: 0)
            OnboardingBottomBar(
                primaryLabel: "onboarding.next",
                primaryAction: { coordinator.advance() },
                primaryDisabled: false,
                skipLabel: "onboarding.skip",
                skipAction: { coordinator.advance() }
            )
        }
    }
}
