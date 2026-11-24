import AppIntents
import SwiftUI
import WidgetKit

/// 控制中心、鎖定畫面、動作按鈕可以放的「開始錄音」（iOS 18 起）。
@available(iOS 18.0, *)
struct StartRecordingControl: ControlWidget {
    /// 系統靠這串字認得使用者放好的那一顆，上架後不准改。
    static let kind = "org.domyweb.misay.start-recording"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenRecordingIntent()) {
                Label("開始錄音", systemImage: "mic")
            }
        }
        .displayName("開始錄音")
        .description("打開米說，直接開始錄。")
    }
}
