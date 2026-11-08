import UIKit
import UserNotifications

/// 方塊 M2：「文字稿好了」通知（S4-3）。整篇潤飾存好、而且使用者不在米說畫面上時才發；點了打開那篇。
/// 鎖定畫面看得到通知，所以只講長度，不放任何一個講過的字。沒有通知權限時送不出去也不會出錯。
struct TranscriptReadyNotice {
    static let transcriptIDKey = "transcriptID"
    static let title = "文字稿好了"

    static func body(durationSeconds: Double) -> String {
        let minutes = Int((durationSeconds / 60).rounded())
        return minutes < 1 ? "剛才那段整理好了，點開看。" : "\(minutes) 分鐘那段整理好了，點開看。"
    }

    @MainActor
    func post(for transcript: Transcript) {
        guard UIApplication.shared.applicationState != .active else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = Self.title
        content.body = Self.body(durationSeconds: transcript.durationSeconds)
        content.sound = .default
        content.userInfo = [Self.transcriptIDKey: transcript.id.uuidString]
        let request = UNNotificationRequest(
            identifier: "org.domyweb.misay.ready.\(transcript.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
