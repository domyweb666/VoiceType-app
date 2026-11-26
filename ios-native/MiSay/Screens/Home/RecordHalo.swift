import SwiftUI

/// 待機錄音鈕後面的呼吸光暈（2026-11-26 米：鈕不吸引人，要像參考圖那樣有光，外圈慢慢脹縮，
/// 讓人覺得麥克風在等他開口）。只是裝飾：點不到、讀屏不唸。減少動態時光暈留著、不脹縮。
struct RecordHalo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            glow
            ring(diameter: Token.Shape.haloDiameter, scale: Token.Motion.haloRingScale)
            ring(diameter: Token.Shape.recordTap, scale: Token.Motion.haloInnerScale)
        }
        .frame(width: Token.Shape.haloDiameter, height: Token.Shape.haloDiameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { startBreathing() }
        // 切到別的分頁再回來會重新出現；不歸零的話值沒變，光圈就不再動。
        .onDisappear { isBreathing = false }
    }

    /// 圓盤後面那團暖光：從圓盤邊緣往外淡掉。
    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Token.Colors.halo.opacity(Token.Halo.glowOpacity), Color.clear],
                    center: .center,
                    startRadius: Token.Shape.recordDisc / 2,
                    endRadius: Token.Shape.haloDiameter / 2
                )
            )
            .scaleEffect(isBreathing ? Token.Motion.haloInnerScale : 1)
    }

    private func ring(diameter: CGFloat, scale: CGFloat) -> some View {
        Circle()
            .fill(Token.Colors.halo.opacity(Token.Halo.ringOpacity))
            .frame(width: diameter, height: diameter)
            .scaleEffect(isBreathing ? scale : 1 / scale)
    }

    private func startBreathing() {
        guard !reduceMotion else {
            return
        }
        let breath = Animation.easeInOut(duration: Token.Motion.haloBreath / 2)
        withAnimation(breath.repeatForever(autoreverses: true)) {
            isBreathing = true
        }
    }
}
