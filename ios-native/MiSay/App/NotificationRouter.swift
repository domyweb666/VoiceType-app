import Observation
import UserNotifications

/// 點通知之後要去哪（S4-3）：「文字稿好了」帶著那篇的 id，分頁列看到就打開它。
/// 要在 App 一啟動就掛上，冷啟動時點的那一下才接得到。米說在前景時通知不跳（照系統預設）。
@MainActor
@Observable
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    /// 分頁列打開之後清成 nil。
    var openTranscriptID: UUID?

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let raw = userInfo[TranscriptReadyNotice.transcriptIDKey] as? String,
              let id = UUID(uuidString: raw)
        else {
            return
        }
        await MainActor.run {
            NotificationRouter.shared.openTranscriptID = id
        }
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
