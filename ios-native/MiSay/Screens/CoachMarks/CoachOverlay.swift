import SwiftUI

/// 聚光燈引導蓋在整個 App 上面的那一層（掛在 `RootTabView`）：黑幕、洞、洞外的光暈、「跳過教學」、說明卡。
/// 引導期間黑幕攔下所有觸控，洞裡的元件也不能點；能按的只有「知道了」和「跳過教學」。
/// 跟規格不一樣的三處：「跳過教學」放左上（右上是要照的複製鈕與「⋯」）；目標沒回報位置時不跳過那一步，
/// 改成不挖洞、說明卡放上面、玉米人往上指；結束後留在原本那一頁，不回第一個分頁。
struct CoachOverlay: View {
    let coach: CoachController

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let step = coach.currentStep {
                GeometryReader { proxy in
                    layers(for: step, screen: proxy.frame(in: .global))
                }
                .transition(.opacity)
            }
        }
        .animation(Token.Coach.fade, value: coach.isActive)
        .sensoryFeedback(.selection, trigger: coach.stepIndex)
    }

    private func layers(for step: CoachStep, screen: CGRect) -> some View {
        let hole = coach.frames[step.targetID]?
            .insetBy(dx: -Token.Coach.holePadding, dy: -Token.Coach.holePadding)
        // 洞在上半部，卡放下面；洞在下半部或沒有洞，卡放上面。卡不會蓋到洞。
        let isCardOnTop = hole.map { $0.midY > screen.midY } ?? true
        let card = CoachCard(
            step: step,
            index: coach.stepIndex,
            count: coach.steps.count,
            onNext: coach.next
        )
        .frame(maxHeight: screen.height * Token.Coach.cardMaxHeightShare)
        .id(step.id)
        .transition(.opacity)

        return ZStack {
            spotlight(hole: hole, isRound: step.isRoundTarget)
            VStack(spacing: Token.Space.s) {
                skipButton
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isCardOnTop {
                    card
                }
                Spacer(minLength: 0)
                if !isCardOnTop {
                    card
                }
            }
            .padding(.horizontal, Token.Space.l)
            .padding(.vertical, Token.Space.s)
            .animation(Token.Coach.cardSwap, value: coach.stepIndex)
            .accessibilityAddTraits(.isModal)
        }
    }

    /// 黑幕與光暈。座標是整個螢幕的，所以這一層不避開安全區域。
    private func spotlight(hole: CGRect?, isRound: Bool) -> some View {
        let rect = hole ?? .zero
        let radius = isRound ? rect.height / 2 : Token.Coach.holeRadius
        let opacity = colorScheme == .dark
            ? Token.Coach.scrimOpacityDark
            : Token.Coach.scrimOpacity
        return SpotlightShape(hole: rect, cornerRadius: radius)
            .fill(Token.Colors.scrim.opacity(opacity), style: FillStyle(eoFill: true))
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Token.Colors.accent, lineWidth: Token.Coach.glowWidth)
                    .shadow(
                        color: Token.Colors.accent.opacity(Token.Coach.glowOpacity),
                        radius: Token.Coach.glowRadius
                    )
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .opacity(hole == nil ? 0 : 1)
            }
            // 減少動態時洞不滑動：每一步換一張新的，用淡出淡入。
            .id(reduceMotion ? coach.stepIndex : 0)
            .transition(.opacity)
            .animation(reduceMotion ? Token.Coach.fade : Token.Coach.holeMove, value: rect)
            // 整片（含洞裡）都收下觸控，底下的東西點不到。
            .contentShape(Rectangle())
            .onTapGesture {}
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private var skipButton: some View {
        Button(action: coach.skip) {
            HStack(spacing: Token.Space.xs) {
                Text("跳過教學")
                Image(systemName: "xmark")
                    .accessibilityHidden(true)
            }
            .font(Token.Fonts.footnote)
            .foregroundStyle(Token.Colors.onScrim)
            .padding(.horizontal, Token.Space.m)
            .padding(.vertical, Token.Space.s)
            .background(
                Token.Colors.scrim.opacity(Token.Coach.skipFillOpacity),
                in: Capsule()
            )
            .frame(minHeight: Token.Shape.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
