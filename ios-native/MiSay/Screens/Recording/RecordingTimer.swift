import SwiftUI

/// 錄音計時（性能檢查 M4，2026-11-26）。
/// 拆成自己一個畫面：`Recorder` 一秒更新 20 次（跟波形一樣快），秒數在面板本體讀的話，整個面板一秒重畫 20 次，
/// 錄一小時就是七萬多次，耗電又發熱。放在這裡只有這一行跟著跳，跟 `RecordingWaveform` 同一個做法。
/// 2026-11-27 B 版：放大到 64 當上半部的主角；首頁待機沒在錄（`recorder` 是 nil）顯示灰的 00:00，
/// 被打斷時也變灰（`isDimmed`），一眼看得出現在沒在收音。
struct RecordingTimer: View {
    let recorder: Recorder?
    var isDimmed = false

    /// 計時字級跟著系統字級放大（使用規則第 5 條）。
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = Token.Fonts.timerSize

    var body: some View {
        let elapsed = RecordingSheetView.formatElapsed(recorder?.elapsedSeconds ?? 0)
        Text(elapsed)
            .font(Token.Fonts.timer(timerSize))
            .foregroundStyle(isDimmed ? Token.Colors.textSecondary : Token.Colors.textPrimary)
            // 超過一小時多兩位、字又放到最大時，縮一點也不要斷成兩行。
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel("已錄 \(elapsed)")
    }
}
