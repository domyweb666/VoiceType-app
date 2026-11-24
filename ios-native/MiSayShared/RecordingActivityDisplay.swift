import Foundation

/// 即時動態現在要講什麼。放共用資料夾是為了單元測試測得到，畫面在小工具擴充。
struct RecordingActivityDisplay: Equatable {
    private static let secondsPerHour: TimeInterval = 3600
    private static let twoDigitHours: TimeInterval = 10 * secondsPerHour

    let title: String
    /// 第二行；平常沒有。
    let hint: String?
    let symbol: String
    /// 過期就不給計時看：那個數字已經不是真的。
    let showsTimer: Bool
    /// 計時最寬會長到多寬。系統的計時文字會撐滿能用的寬度，靠這串字把它框住。
    let timerTemplate: String

    init(state: RecordingActivityAttributes.ContentState, isStale: Bool) {
        showsTimer = !isStale
        timerTemplate = Self.template(for: state)
        guard !isStale else {
            title = "錄音已停"
            hint = "打開米說看看"
            symbol = "mic.slash.fill"
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

    /// 看計時「會走到」多長，不看現在多長：下次更新前跨過一小時也不破版。
    private static func template(for state: RecordingActivityAttributes.ContentState) -> String {
        let longest = (state.pausedAt ?? state.timerEnd).timeIntervalSince(state.timerStart)
        if longest >= twoDigitHours {
            return "00:00:00"
        }
        return longest >= secondsPerHour ? "0:00:00" : "00:00"
    }
}
