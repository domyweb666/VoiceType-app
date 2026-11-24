import Foundation
import UIKit

/// 方塊 M1：錄音狀態要怎麼變成即時動態的內容、什麼時候才值得送一次。
/// 純邏輯不碰 ActivityKit，單元測試測得到；`RecordingActivityPresenter` 每秒問它一次。
struct RecordingActivityPlan {
    typealias State = RecordingActivityAttributes.ContentState

    /// `Recorder` 現在的樣子。
    struct Status: Equatable {
        var isPaused: Bool
        var isWaitingForSound: Bool
        var elapsedSeconds: Double
    }

    /// 要送出去的一次。
    struct Frame: Equatable {
        var state: State
        /// 畫面上還沒有的話，這一次可不可以新開（系統只准在前景開）。
        var canStart: Bool

        var staleDate: Date {
            state.timerEnd
        }
    }

    /// 5 分鐘沒續期才當作錄音死了。續期連漏好幾次才會誤判，所以長錄音在背景也不會。
    /// App 真的被殺時，90 秒就有 `RecordingAlarm` 的通知，這裡不用搶快。
    static let staleAfterSeconds: TimeInterval = 300
    /// 一分鐘送一次，不耗電；數字由系統自己走。
    static let renewAfterSeconds: TimeInterval = 60
    /// 計時差不到這麼多就沿用舊的起點，續期時數字才不會來回跳。
    static let driftLimitSeconds: TimeInterval = 2

    private var lastState: State?
    private var lastSentAt = Date.distantPast
    private var wasAppActive = false

    /// 要送才回東西。狀態變了馬上送，沒變就等續期；回到前景多送一次，讓不見的可以再開。
    mutating func next(
        _ status: Status,
        appState: UIApplication.State,
        now: Date
    ) -> Frame? {
        let isFirst = lastState == nil
        let canStart = isFirst ? appState != .background : appState == .active && !wasAppActive
        wasAppActive = appState == .active
        let state = Self.state(for: status, after: lastState, now: now)
        let isRenewalDue = now.timeIntervalSince(lastSentAt) >= Self.renewAfterSeconds
        guard canStart || isRenewalDue || hasChanged(to: state) else {
            return nil
        }
        lastState = state
        lastSentAt = now
        return Frame(state: state, canStart: canStart)
    }

    /// 已錄長度用 `Recorder` 的秒數（跟錄音面板同一個），不用牆上的時間：中間斷掉的不算。
    static func state(for status: Status, after previous: State?, now: Date) -> State {
        var state = State(
            phase: phase(for: status),
            timerStart: now.addingTimeInterval(-status.elapsedSeconds),
            timerEnd: now.addingTimeInterval(staleAfterSeconds),
            pausedAt: now
        )
        guard state.phase == .recording else {
            return state
        }
        state.pausedAt = nil
        if let previous, previous.phase == .recording {
            let drift = abs(previous.timerStart.timeIntervalSince(state.timerStart))
            if drift < driftLimitSeconds {
                state.timerStart = previous.timerStart
            }
        }
        return state
    }

    private static func phase(for status: Status) -> RecordingActivityPhase {
        if status.isPaused {
            return .paused
        }
        return status.isWaitingForSound ? .waitingForSound : .recording
    }

    /// 沒在收音時起點每秒都在往後移（長度沒變），不算變。
    private func hasChanged(to state: State) -> Bool {
        guard let lastState, lastState.phase == state.phase else {
            return true
        }
        return state.phase == .recording && lastState.timerStart != state.timerStart
    }
}
