import SwiftUI
import WidgetKit

/// 只放即時動態與控制中心按鈕，不放主畫面小工具：小工具清單裡不會冒出沒有用的項目。
@main
struct MiSayWidgetBundle: WidgetBundle {
    /// 這裡的 if 只准判斷 iOS 版本、不准接 else（WidgetBundleBuilder 的限制）。
    var body: some Widget {
        RecordingLiveActivity()
        if #available(iOS 18.0, *) {
            StartRecordingControl()
        }
    }
}
