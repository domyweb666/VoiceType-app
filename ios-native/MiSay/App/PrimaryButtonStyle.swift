import SwiftUI

/// 玉米黃膠囊（使用規則第 2、15 條）：每個畫面只有一顆，整寬、`primaryTap` 高。
/// 停用與按下都用透明度表示，數字在 `Token.Motion`。
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let opacity = Token.Motion.buttonOpacity(
            isEnabled: isEnabled,
            isPressed: configuration.isPressed
        )
        return configuration.label
            .font(Token.Fonts.rowTitle)
            .foregroundStyle(Token.Colors.actionInk)
            .frame(maxWidth: .infinity, minHeight: Token.Shape.primaryTap)
            .background(Token.Colors.actionFill, in: Capsule())
            .opacity(opacity)
    }
}
