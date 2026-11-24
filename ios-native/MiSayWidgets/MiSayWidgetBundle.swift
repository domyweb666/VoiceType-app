import SwiftUI
import WidgetKit

/// 只放即時動態，不放主畫面小工具：小工具清單裡不會冒出沒有用的項目。
@main
struct MiSayWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivity()
    }
}
