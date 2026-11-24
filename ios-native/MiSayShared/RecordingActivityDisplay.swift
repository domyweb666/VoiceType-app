import Foundation

/// 即時動態現在要講什麼。放共用資料夾是為了單元測試測得到，畫面在小工具擴充。
struct RecordingActivityDisplay: Equatable {
    private static let secondsPerHour: TimeInterval = 3600
    private static let twoDigitHours: TimeInterval = 10 * secondsPerHour
    /// 計時框先留這麼久以後的寬度：下次更新前跨過一小時也不破版。
    private static let timerRoomSeconds: TimeInterval = 300

    let title: String
    /// 第二行；平常沒有。
    let hint: String?
    let symbol: String
    /// 過期就不給計時看：不知道是不是還在錄，數字不能信。
    let showsTimer: Bool
    /// 計時最寬會長到多寬。系統的計時文字會撐滿能用的寬度，靠這串字把它框住。
    let timerTemplate: String

    /// 過期只代表太久沒更新。系統可能擋掉背景更新（論壇 748569），錄音好好的也會走到這裡，
    /// 所以不准寫成「已停」。
    init(
        state: RecordingActivityAttributes.ContentState,
        isStale: Bool,
        now: Date = Date()
    ) {
        showsTimer = !isStale
        timerTemplate = Self.template(for: state, now: now)
        guard !isStale else {
            title = "狀態沒更新"
            hint = "打開米說看看"
            symbol = "questionmark"
            return
        }
        hint = nil
        switch state.phase {
        case .recording:
            title = "錄音中"
            symbol = "mic.fill"
        case .paused:
            title = "已暫停"
            symbol = "pause.fill"
        case .waitingForSound:
            title = "等聲音"
            symbol = "ear.fill"
        }
    }

    /// 給人聽的：靈動島上只有一個圖示，要唸得出是哪個 App。
    var spokenTitle: String {
        "米說\(title)"
    }

    /// 靈動島上沒有地方放第二行，唸的時候一起講。
    var spokenSummary: String {
        hint.map { "\(spokenTitle)，\($0)" } ?? spokenTitle
    }

    private static func template(
        for state: RecordingActivityAttributes.ContentState,
        now: Date
    ) -> String {
        let shownUntil = state.pausedAt ?? now.addingTimeInterval(timerRoomSeconds)
        let longest = shownUntil.timeIntervalSince(state.timerStart)
        if longest >= twoDigitHours {
            return "00:00:00"
        }
        return longest >= secondsPerHour ? "0:00:00" : "00:00"
    }
}
