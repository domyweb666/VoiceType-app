import SwiftUI

/// 錄音畫面的聲波（2026-11-27 B 版：一排細直條橫跨整寬，放在上半部當主角）。
/// 最新的聲音在右邊，越舊越淡。首頁待機沒在錄（`recorder` 是 nil）是一排平平的灰條；
/// 被打斷時（`isDimmed`）留著剛才的起伏、改成灰的。
/// 減少動態時不畫一排會跳的柱子，改成一條固定位置的音量條（手感參數表）。
struct RecordingWaveform: View {
    let recorder: Recorder?
    var height = Token.Shape.stageWaveHeight
    var isDimmed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                levelBar
            } else {
                bars
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private var color: Color {
        isDimmed || recorder == nil ? Token.Colors.textTertiary : Token.Colors.waveform
    }

    private var levelBar: some View {
        let level = recorder?.level ?? 0
        return GeometryReader { geometry in
            Capsule()
                .fill(color)
                .frame(
                    width: max(Token.Shape.waveBarMin, geometry.size.width * level),
                    height: Token.Space.s
                )
                .frame(maxHeight: .infinity)
        }
    }

    private var bars: some View {
        let levels = recorder?.levels ?? Array(repeating: 0, count: Recorder.levelHistoryCount)
        let count = max(levels.count - 1, 1)
        return HStack(alignment: .center, spacing: CGFloat.zero) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                Capsule()
                    .fill(color.opacity(Self.opacity(at: index, of: count)))
                    .frame(
                        width: Token.Shape.waveBarWidth,
                        height: max(Token.Shape.waveBarMin, height * level)
                    )
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// 最左邊（最舊）最淡，往右漸濃到不透明。
    private static func opacity(at index: Int, of lastIndex: Int) -> Double {
        let oldest = Token.Halo.waveOldestOpacity
        return oldest + (1 - oldest) * Double(index) / Double(lastIndex)
    }
}
