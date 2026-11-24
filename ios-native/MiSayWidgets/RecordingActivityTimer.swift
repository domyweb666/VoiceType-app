import SwiftUI

/// 系統自己走的計時。系統的計時文字會把能用的寬度吃滿、把靈動島撐開，
/// 所以先放一串看不見、一樣寬的字占位置，計時疊在上面。
struct RecordingActivityTimer: View {
    /// 字級開很大時寧可縮小，不要被切掉。
    private static let smallestScale = 0.5

    let state: RecordingActivityAttributes.ContentState
    let display: RecordingActivityDisplay

    var body: some View {
        if display.showsTimer {
            Text(display.timerTemplate)
                .hidden()
                .overlay(alignment: .trailing) {
                    Text(
                        timerInterval: state.timerRange,
                        pauseTime: state.pausedAt,
                        countsDown: false
                    )
                    .multilineTextAlignment(.trailing)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Self.smallestScale)
        }
    }
}
