import SwiftUI

/// 主要按鈕（使用規則第 2、15 條）：每個畫面只有一顆，膠囊。
/// 2026-11-14 照 domy-design：金棕底（`accent`）白字；玉米黃只留給錄音大鈕。
/// 空狀態裡那顆用 `isCompact`：字小一級、不撐滿整寬（domy 的 compact）。
/// 裡面是系統按鈕（2026-11-08 米選原生）：iOS 26 是玻璃凸起樣式，舊系統是 borderedProminent，
/// 高度、按下、停用的樣子交給系統。外面照舊寫 `.buttonStyle(PrimaryButtonStyle())`。
struct PrimaryButtonStyle: PrimitiveButtonStyle {
    var isCompact = false

    func makeBody(configuration: Configuration) -> some View {
        let button = Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(isCompact ? Token.Fonts.callout : Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.onAccent)
                .frame(maxWidth: isCompact ? nil : CGFloat.infinity, minHeight: Token.Shape.minTap)
        }
        .controlSize(isCompact ? .regular : .large)
        .buttonBorderShape(.capsule)
        .tint(Token.Colors.accent)

        if #available(iOS 26, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }
}
