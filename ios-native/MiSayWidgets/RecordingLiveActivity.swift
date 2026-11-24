import ActivityKit
import SwiftUI
import WidgetKit

/// LA1 的最小畫面，證明編得過、簽得過；還沒有任何地方啟動它，樣子由 LA2 做。
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            HStack {
                Text("錄音中")
                Spacer()
                Text(context.state.startedAt, style: .timer)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("錄音中")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                }
            } compactLeading: {
                Image(systemName: "mic")
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
            } minimal: {
                Image(systemName: "mic")
            }
        }
    }
}
