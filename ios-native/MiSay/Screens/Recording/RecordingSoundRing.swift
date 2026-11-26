import SwiftUI

/// 首頁錄音中環繞圓盤的聲波（2026-11-26 米：聲波環繞在麥克風周圍，一看就知道跟聲音有關）。
/// 一圈放射狀音量條跟著聲音起伏，再加兩圈從圓盤往外擴散、慢慢淡掉的聲波環。
/// `Recorder` 一秒更新 20 次，只有這一塊跟著重畫，跟 `RecordingTimer`、`RecordingWaveform` 同一個做法。
/// 減少動態時不畫會跳、會擴散的東西，改成一圈隨音量變粗細的環。
struct RecordingSoundRing: View {
    let recorder: Recorder

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                steadyRing
            } else {
                movingRing
            }
        }
        .frame(width: Token.Shape.soundRing, height: Token.Shape.soundRing)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var steadyRing: some View {
        Circle()
            .stroke(
                Token.Colors.waveform.opacity(Token.Halo.waveBase + Token.Halo.waveLevel),
                lineWidth: Token.Shape.soundBarMin
                    + Token.Shape.soundBarMax * CGFloat(recorder.level)
            )
            .frame(width: Token.Shape.recordTap, height: Token.Shape.recordTap)
    }

    private var movingRing: some View {
        TimelineView(.animation(minimumInterval: 1 / Token.Motion.waveformHz)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let levels = recorder.levels
            let level = recorder.level
            Canvas { context, size in
                Self.drawWaves(in: &context, size: size, seconds: seconds, level: level)
                Self.drawBars(in: &context, size: size, levels: levels)
            }
        }
    }

    /// 往外擴散的聲波環：從圓盤邊緣出發，走到外緣淡掉；越大聲越濃。
    private static func drawWaves(
        in context: inout GraphicsContext,
        size: CGSize,
        seconds: Double,
        level: Double
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let start = Token.Shape.recordDisc / 2
        let end = min(size.width, size.height) / 2
        let strength = Token.Halo.waveBase + Token.Halo.waveLevel * level
        for wave in 0 ..< Token.Shape.soundWaveCount {
            let offset = Double(wave) / Double(Token.Shape.soundWaveCount)
            let travelled = seconds / Token.Motion.soundWaveSeconds + offset
            let progress = travelled.truncatingRemainder(dividingBy: 1)
            let radius = start + (end - start) * CGFloat(progress)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(Token.Colors.waveform.opacity((1 - progress) * strength)),
                lineWidth: Token.Shape.soundWaveLine
            )
        }
    }

    /// 繞圓盤一圈的音量條。左右對稱：正上方是最新的聲音，往下兩邊是比較早的。
    private static func drawBars(
        in context: inout GraphicsContext,
        size: CGSize,
        levels: [Double]
    ) {
        guard !levels.isEmpty else {
            return
        }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let inner = Token.Shape.recordDisc / 2 + Token.Space.m
        let count = Token.Shape.soundBarCount
        let half = count / 2
        var path = Path()
        for index in 0 ..< count {
            let fromTop = index < half ? index : count - 1 - index
            let age = Double(fromTop) / Double(half)
            let sample = levels.count - 1 - min(levels.count - 1, Int(age * Double(levels.count)))
            let length = Token.Shape.soundBarMin + Token.Shape.soundBarMax * CGFloat(levels[sample])
            let angle = Double(index) / Double(count) * 2 * Double.pi - Double.pi / 2
            let across = CGFloat(cos(angle))
            let down = CGFloat(sin(angle))
            path.move(to: CGPoint(x: center.x + across * inner, y: center.y + down * inner))
            path.addLine(to: CGPoint(
                x: center.x + across * (inner + length),
                y: center.y + down * (inner + length)
            ))
        }
        context.stroke(
            path,
            with: .color(Token.Colors.waveform),
            style: StrokeStyle(lineWidth: Token.Shape.soundBarWidth, lineCap: .round)
        )
    }
}
