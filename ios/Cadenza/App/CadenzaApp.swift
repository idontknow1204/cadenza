import SwiftUI

// MARK: - AppDelegate (APNs 토큰 콜백 브릿지)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.didRegister(tokenData: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[Push] APNs 등록 실패: \(error)")
        #endif
    }
}

// MARK: - App

@main
struct CadenzaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var session = SessionStore()
    @AppStorage("appLanguage") private var appLanguage: String = ""
    @AppStorage("languageChosen") private var languageChosen: Bool = false
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
                    } else if session.isPasswordRecovery {
                        ResetPasswordView()
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
            .onOpenURL { session.handleURL($0) }
            .id(appLanguage)
            .environment(session)
            .environment(\.locale, appLanguage.isEmpty ? .current : Locale(identifier: appLanguage))
            .tint(.accentColor)
            .progressViewStyle(CadenzaProgressViewStyle())
        }
    }
}

// MARK: - Splash

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
