import UIKit
import UserNotifications

// MARK: - Manager

@MainActor
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    var onTokenRegistered: ((String) -> Void)?
    var onNotificationTap: (() -> Void)?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// 알림 권한 요청 + APNs 등록. 이미 허용된 경우 바로 등록.
    func requestPermissionAndRegister() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                await UIApplication.shared.registerForRemoteNotifications()
            case .notDetermined:
                do {
                    let granted = try await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .badge, .sound])
                    if granted {
                        await UIApplication.shared.registerForRemoteNotifications()
                    }
                } catch {
                    #if DEBUG
                    print("[Push] 권한 요청 실패: \(error)")
                    #endif
                }
            default:
                break
            }
        }
    }

    /// UIApplicationDelegate 에서 수신한 토큰 데이터를 16진수 문자열로 변환해 전달.
    func didRegister(tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        onTokenRegistered?(token)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// 포그라운드 상태에서 알림 수신 시 배너+배지+소리 표시.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .badge, .sound])
    }

    /// 알림 탭 시 알림 탭으로 이동.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        Task { @MainActor in self.onNotificationTap?() }
        handler()
    }
}
