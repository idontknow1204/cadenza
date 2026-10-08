import SwiftUI

struct Step8VisibilityView: View {
    @Bindable var coordinator: OnboardingCoordinator
    @Environment(SessionStore.self) private var session

    private let options: [(Visibility, String, String)] = [
        (.industryFollowers, "visibility.industry",  "person.2.fill"),
        (.public,            "visibility.public",    "globe"),
        (.followers,         "visibility.followers", "person.fill"),
        (.private,           "visibility.private",   "lock.fill"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    visibilityPicker
                    explanationCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .adaptiveContentWidth()
            }
            Spacer(minLength: 0)
            OnboardingBottomBar(
                primaryLabel: "onboarding.done",
                primaryAction: {
                    guard let uid = session.currentUserID else { return }
                    Task {
                        await coordinator.completeOnboarding(
                            repo: session.repo, userID: uid, session: session
                        )
                    }
                },
                primaryDisabled: false,
                isBusy: coordinator.isBusy
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("onboarding.step8.title").font(.largeTitle.bold())
            Text("onboarding.step8.desc").foregroundStyle(.secondary)
        }
    }

    private var visibilityPicker: some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.0) { visibility, labelKey, icon in
                let selected = coordinator.defaultVisibility == visibility
                Button {
                    coordinator.defaultVisibility = visibility
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 28)
                            .foregroundStyle(selected ? Color.white : Color.accentColor)
                        Text(LocalizedStringKey(labelKey))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selected ? .white : .primary)
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(selected ? Color.accentColor : Color.secondary.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.12), value: selected)
            }
        }
    }

    private var explanationCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(Color.accentColor)
            Text("onboarding.step8.note")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

    }
}
