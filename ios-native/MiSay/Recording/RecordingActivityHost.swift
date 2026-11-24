import ActivityKit
import Foundation

/// 方塊 M1：App 裡唯一呼叫 ActivityKit 的地方，一次做一件。
/// 任何失敗都只是畫面上沒有那一塊，不往外拋。
struct RecordingActivityHost {
    enum Command {
        /// 上次 App 被殺留在畫面上的。
        case endLeftovers
        case show(RecordingActivityPlan.Frame)
        case end
    }

    /// 官方上限，到了系統會自己收掉。
    static let systemLimitSeconds: TimeInterval = 8 * 60 * 60

    private var activity: Activity<RecordingActivityAttributes>?
    /// 這段錄音上一次開成功的時間；沒開過是 nil。
    private var startedAt: Date?

    /// 使用者自己滑掉的，這段錄音就不再冒出來；滿 8 小時被系統收掉的可以再開一個。
    static func canStart(lastStartedAt: Date?, now: Date) -> Bool {
        guard let lastStartedAt else {
            return true
        }
        return now.timeIntervalSince(lastStartedAt) >= systemLimitSeconds
    }

    mutating func handle(_ command: Command) async {
        switch command {
        case .endLeftovers:
            // 已經開了一個，就是正在錄的那個，不准收。
            if activity == nil {
                await endAll()
            }
        case let .show(frame):
            await show(frame)
        case .end:
            await endAll()
            activity = nil
            startedAt = nil
        }
    }

    private mutating func show(_ frame: RecordingActivityPlan.Frame) async {
        let content = ActivityContent(state: frame.state, staleDate: frame.staleDate)
        if let activity, Self.isOnScreen(activity) {
            await activity.update(content)
            return
        }
        guard frame.canStart, Self.canStart(lastStartedAt: startedAt, now: Date()),
              ActivityAuthorizationInfo().areActivitiesEnabled
        else {
            return
        }
        await endAll()
        do {
            activity = try Activity.request(
                attributes: RecordingActivityAttributes(),
                content: content,
                pushType: nil
            )
            startedAt = Date()
        } catch {
            DiagnosticLog.shared.record("即時動態沒開成：\(error)")
        }
    }

    private func endAll() async {
        // 滿 8 小時的那個可能已經不在清單裡，鎖定畫面上還看得到，所以自己那個另外收。
        if let activity {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        for leftover in Activity<RecordingActivityAttributes>.activities {
            await leftover.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func isOnScreen(_ activity: Activity<RecordingActivityAttributes>) -> Bool {
        activity.activityState != .ended && activity.activityState != .dismissed
    }
}
