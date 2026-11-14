import SwiftUI

/// 文字鈕（使用規則第 11 條）：沒有底，只有字。
/// 2026-11-14 照 domy-design 的 plain：深金（`link`）、字跟主要按鈕同一級。
/// 裡面是系統的 borderless 按鈕，按下變淡交給系統；點擊範圍至少 `minTap` 高。
/// 外面照舊寫 `.buttonStyle(TextButtonStyle())`。
struct TextButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(Token.Fonts.rowTitle)
                .frame(minHeight: Token.Shape.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .tint(Token.Colors.link)
    }
}
