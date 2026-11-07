import SwiftUI

/// 金色文字鈕（使用規則第 11 條）：`minTap` 高，左右留 `Space.l` 讓手指按得到。
struct TextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let opacity = Token.Motion.buttonOpacity(
            isEnabled: isEnabled,
            isPressed: configuration.isPressed
        )
        return configuration.label
            .font(Token.Fonts.body.weight(.medium))
            .foregroundStyle(Token.Colors.link)
            .padding(.horizontal, Token.Space.l)
            .frame(minHeight: Token.Shape.minTap)
            .contentShape(Rectangle())
            .opacity(opacity)
    }
}
