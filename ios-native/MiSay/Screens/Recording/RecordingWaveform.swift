import SwiftUI

/// 錄音面板的波形。減少動態時不畫一排會跳的柱子，改成一條固定位置的音量條（手感參數表）。
struct RecordingWaveform: View {
    let recorder: Recorder

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: Token.Space.xs)
                    .fill(Token.Colors.waveform)
                    .frame(width: geometry.size.width * recorder.level)
            }
            .frame(height: Token.Space.s)
            .accessibilityHidden(true)
        } else {
            HStack(alignment: .center, spacing: Token.Space.xs) {
                ForEach(Array(recorder.levels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: Token.Space.xs)
                        .fill(Token.Colors.waveform)
                        .frame(
                            width: Token.Space.xs,
                            height: max(Token.Space.xs, Token.Shape.primaryTap * level)
                        )
                }
            }
            .frame(height: Token.Shape.primaryTap)
            .accessibilityHidden(true)
        }
    }
}
