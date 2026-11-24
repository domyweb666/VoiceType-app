import ActivityKit
import Foundation

/// 錄音中的即時動態（組塊 LA）。App 與小工具擴充要編進同一份定義，系統才對得起來。
struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
    }
}
