import SwiftUI

@main
struct CadenzaApp: App {
    @State private var session = SessionStore()
    @AppStorage("appLanguage") private var appLanguage: String = ""
    @AppStorage("languageChosen") private var languageChosen: Bool = false
    // Show landing splash on every cold launch after language has been chosen.
    // First launch (languageChosen == false) uses LanguagePickerView's own splash.
    @State private var isShowingLanding = UserDefaults.standard.bool(forKey: "languageChosen")

    init() {
        LanguageBundle.activate()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if !languageChosen {
                        LanguagePickerView()
                    } else if session.isBootstrapping {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if session.session == nil {
                        AuthView()
                    } else if session.needsOnboarding {
                        OnboardingView()
                    } else {
                        RootTabView()
                    }
                }

                if isShowingLanding {
                    AppLandingView()
                        .transition(.opacity)
                        .zIndex(1)
                        .task {
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isShowingLanding = false
                            }
                        }
                }
            }
            .id(appLanguage)
            .environment(session)
            .environment(\.locale, appLanguage.isEmpty ? .current : Locale(identifier: appLanguage))
            .tint(.accentColor)
            .progressViewStyle(CadenzaProgressViewStyle())
        }
    }
}

private struct AppLandingView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    Image("CadenzaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .padding(.bottom, -24)
                    Text("Cadenza")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.black)
                }
                Spacer()
            }
        }
        .preferredColorScheme(.light)
    }
}
