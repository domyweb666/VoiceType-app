import SwiftUI

/// 錄音面板最上面那行計時（性能檢查 M4，2026-11-26）。
/// 拆成自己一個畫面：`Recorder` 一秒更新 20 次（跟波形一樣快），秒數在面板本體讀的話，整個面板一秒重畫 20 次，
/// 錄一小時就是七萬多次，耗電又發熱。放在這裡只有這一行跟著跳，跟 `RecordingWaveform` 同一個做法。
struct RecordingTimer: View {
    let recorder: Recorder

    /// 計時字級跟著系統字級放大（使用規則第 5 條）。
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = Token.Fonts.timerSize

    var body: some View {
        let elapsed = RecordingSheetView.formatElapsed(recorder.elapsedSeconds)
        Text(elapsed)
            .font(Token.Fonts.timer(timerSize))
            .foregroundStyle(Token.Colors.textPrimary)
            .accessibilityLabel("已錄 \(elapsed)")
    }
}
