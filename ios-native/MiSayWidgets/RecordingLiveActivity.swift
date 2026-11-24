import ActivityKit
import SwiftUI
import WidgetKit

/// 錄音中的即時動態：鎖定畫面與靈動島。點下去打開米說（沒設網址，系統預設），錄音面板還在上面。
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            RecordingLockScreenView(state: context.state, display: Self.display(for: context))
        } dynamicIsland: { context in
            Self.island(state: context.state, display: Self.display(for: context))
        }
    }

    private static func display(
        for context: ActivityViewContext<RecordingActivityAttributes>
    ) -> RecordingActivityDisplay {
        RecordingActivityDisplay(state: context.state, isStale: context.isStale)
    }

    /// 靈動島的底永遠是黑的，字與圖示用玉米黃（淺深色同值）。
    private static func island(
        state: RecordingActivityAttributes.ContentState,
        display: RecordingActivityDisplay
    ) -> DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                Label(display.title, systemImage: display.symbol)
                    .font(DomyTokens.TypeScale.headline.font)
                    .foregroundStyle(DomyTheme.gold.bright)
                    .accessibilityLabel(display.spokenTitle)
            }
            DynamicIslandExpandedRegion(.trailing) {
                RecordingActivityTimer(state: state, display: display)
                    .font(DomyTokens.TypeScale.title2.font)
                    .foregroundStyle(DomyTheme.gold.bright)
            }
            DynamicIslandExpandedRegion(.bottom) {
                if let hint = display.hint {
                    Text(hint)
                        .font(DomyTokens.TypeScale.subheadline.font)
                }
            }
        } compactLeading: {
            icon(display)
        } compactTrailing: {
            if display.showsTimer {
                RecordingActivityTimer(state: state, display: display)
                    .font(DomyTokens.TypeScale.callout.font)
                    .foregroundStyle(DomyTheme.gold.bright)
            } else {
                Text("已停")
                    .font(DomyTokens.TypeScale.callout.font)
                    .foregroundStyle(DomyTheme.gold.bright)
            }
        } minimal: {
            // 最小那顆圓放不下會走的時間，只放圖示。
            icon(display)
        }
        .keylineTint(DomyTheme.gold.bright)
    }

    private static func icon(_ display: RecordingActivityDisplay) -> some View {
        Image(systemName: display.symbol)
            .foregroundStyle(DomyTheme.gold.bright)
            .accessibilityLabel(display.spokenTitle)
    }
}
