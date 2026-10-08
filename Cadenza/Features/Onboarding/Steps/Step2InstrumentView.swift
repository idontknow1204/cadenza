import SwiftUI

struct Step2InstrumentView: View {
    @Bindable var coordinator: OnboardingCoordinator
    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    majorSection
                    if !coordinator.major.isEmpty { instrumentSection }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .adaptiveContentWidth()
            }

            Spacer(minLength: 0)

            OnboardingBottomBar(
                primaryLabel: "onboarding.next",
                primaryAction: {
                    Task { await coordinator.saveStep2(repo: session.repo, userID: session.currentUserID!) }
                },
                primaryDisabled: coordinator.major.isEmpty || coordinator.instrument.isEmpty,
                isBusy: coordinator.isBusy
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("onboarding.step2.title").font(.largeTitle.bold())
            Text("onboarding.step2.desc").foregroundStyle(.secondary)
        }
    }

    private var majorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("onboarding.major").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(OnboardingData.majors) { major in
                    SelectChip(label: major.localizedName, selected: coordinator.major == major.id) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            coordinator.major = major.id
                            coordinator.instrument = ""
                        }
                    }
                }
            }
        }
    }

    private var instrumentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("onboarding.instrument").font(.headline)
            let instruments = OnboardingData.instrumentsByMajor[coordinator.major] ?? []
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(instruments) { inst in
                    SelectChip(label: inst.localizedName, selected: coordinator.instrument == inst.id) {
                        coordinator.instrument = inst.id
                    }
                }
            }
        }
    }
}

struct SelectChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                // Fixed height keeps every chip identical regardless of label
                // length or line count, so rows never end up jagged.
                .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: selected)
    }
}
