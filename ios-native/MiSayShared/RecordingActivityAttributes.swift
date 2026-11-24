import ActivityKit
import Foundation

/// 錄音中的即時動態（組塊 LA）。App 與小工具擴充要編進同一份定義，系統才對得起來。
struct RecordingActivityAttributes: ActivityAttributes {
    /// 只有狀態與時間：鎖定畫面誰都看得到，文字稿內容不准進來。
    struct ContentState: Codable, Hashable {
        var phase: RecordingActivityPhase
        /// 現在減掉已錄長度。計時由系統自己從這裡走，不用每秒更新。
        var timerStart: Date
        /// 系統計時要一個終點。放很遠：沒續到期不代表錄音停了，計時不准停在半路裝成停了。
        var timerEnd: Date
        /// 沒在收音時計時停在這一刻；錄音中是 nil。
        var pausedAt: Date?

        /// 區間頭尾顛倒會當掉，這裡保證不會。
        var timerRange: ClosedRange<Date> {
            timerStart ... max(timerStart, timerEnd)
        }
    }
}
