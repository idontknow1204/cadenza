import SwiftUI

struct OnboardingView: View {
    @Environment(SessionStore.self) private var session
    @State private var coordinator = OnboardingCoordinator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar (hidden on consent step — no navigation back needed)
                if coordinator.step > 1 {
                    ProgressBar(current: coordinator.step - 1, total: coordinator.totalSteps - 1)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // Step content
                Group {
                    switch coordinator.step {
                    case 1: Step1ConsentView(coordinator: coordinator)
                    case 2: Step2InstrumentView(coordinator: coordinator)
                    case 3: Step3AffiliationView(coordinator: coordinator)
                    case 4: Step4TeacherView(coordinator: coordinator)
                    case 5: Step5ProfileView(coordinator: coordinator)
                    case 6: Step6ActivityView(coordinator: coordinator)
                    case 7: Step7ContactsView(coordinator: coordinator)
                    default: Step8VisibilityView(coordinator: coordinator)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .animation(.easeInOut(duration: 0.22), value: coordinator.step)
            }
            .toolbar {
                if coordinator.step > 2 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { withAnimation { coordinator.back() } } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
            .alert("error.title", isPresented: .constant(coordinator.errorText != nil)) {
                Button("common.ok") { coordinator.errorText = nil }
            } message: { Text(coordinator.errorText ?? "") }
        }
        .environment(coordinator)
    }
}

// MARK: - Shared progress bar

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 4) {
                ForEach(2...total, id: \.self) { step in
                    Capsule()
                        .fill(step <= current ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 4)
                }
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Shared bottom button bar

struct OnboardingBottomBar: View {
    let primaryLabel: LocalizedStringKey
    let primaryAction: () -> Void
    let primaryDisabled: Bool
    var skipLabel: LocalizedStringKey? = nil
    var skipAction: (() -> Void)? = nil
    var isBusy: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 12) {
                Button(action: primaryAction) {
                    Group {
                        if isBusy { ProgressView().tint(.white) }
                        else { Text(primaryLabel).fontWeight(.semibold).frame(maxWidth: .infinity) }
                    }
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                }
                .background(
                    (primaryDisabled || isBusy) ? Color.accentColor.opacity(0.3) : Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
                .disabled(primaryDisabled || isBusy)

                if let skipLabel, let skipAction {
                    Button(action: skipAction) {
                        Text(skipLabel)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .adaptiveContentWidth()
        }
    }
}
