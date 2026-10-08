import SwiftUI

/// Prompts the user to add their first activity. Opens CreateActivityView as a
/// sheet; posting OR dismissing both advance to step 7.
struct Step6ActivityView: View {
    @Bindable var coordinator: OnboardingCoordinator
    @State private var showCreate = false
    @State private var posted = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentColor)
                        Text("onboarding.step6.title").font(.largeTitle.bold())
                        Text("onboarding.step6.desc")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    if posted {
                        Label("onboarding.step6.done", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.headline)
                    } else {
                        Button {
                            showCreate = true
                        } label: {
                            Label("onboarding.step6.cta", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 24)
                .adaptiveContentWidth()
            }
            Spacer(minLength: 0)
            OnboardingBottomBar(
                primaryLabel: posted ? "onboarding.next" : "onboarding.step6.skip",
                primaryAction: { coordinator.advance() },
                primaryDisabled: false,
                skipLabel: posted ? nil : nil,
                skipAction: nil
            )
        }
        .sheet(isPresented: $showCreate) {
            CreateActivityView(onPost: { _ in
                posted = true
                showCreate = false
            })
        }
    }
}
