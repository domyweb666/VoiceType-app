import SwiftUI

/// 金色文字鈕（使用規則第 11 條）：沒有底，只有字。
/// 2026-11-08 米選原生：裡面換成系統的 borderless 按鈕，按下變淡交給系統；點擊範圍至少 `minTap` 高。
/// 外面照舊寫 `.buttonStyle(TextButtonStyle())`。
struct TextButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(Token.Fonts.body.weight(.medium))
                .frame(minHeight: Token.Shape.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .tint(Token.Colors.link)
    }
}
