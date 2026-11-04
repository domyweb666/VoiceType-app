import Foundation
import UserNotifications

/// 方塊 M1：「沒在錄了」的提醒。錄音正常時一直把這則通知往後推；App 被殺、當掉、卡住時沒人推，時間到就響。
/// 這是唯一不靠 App 活著的提醒。沒有通知權限時送不出去也不會出錯，錄音照常。
struct RecordingAlarm {
    static let identifier = "org.domyweb.misay.recording-alarm"
    static let fireAfterSeconds: TimeInterval = 90
    static let title = "米說沒在錄了"
    static let body = "已錄到的都在。打開米說看看。"

    /// 同一個 identifier 會蓋掉還沒發出去的那一則，等於往後推；已經響過的那則也收掉，聲音回來了。
    func pushBack() {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
        let content = UNMutableNotificationContent()
        content.title = Self.title
        content.body = Self.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.fireAfterSeconds,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: trigger
        )
        center.add(request, withCompletionHandler: nil)
    }

    func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}
