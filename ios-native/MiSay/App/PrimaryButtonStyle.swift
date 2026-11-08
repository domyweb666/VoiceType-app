import SwiftUI

/// 主要按鈕（使用規則第 2、15 條）：每個畫面只有一顆，整寬膠囊、玉米黃。
/// 2026-11-08 米選原生：裡面換成系統按鈕，iOS 26 是玻璃凸起樣式，舊系統是 borderedProminent。
/// 按下、停用的樣子都交給系統。外面照舊寫 `.buttonStyle(PrimaryButtonStyle())`。
struct PrimaryButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let button = Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.actionInk)
                .frame(maxWidth: .infinity, minHeight: Token.Shape.minTap)
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .tint(Token.Colors.actionFill)

        if #available(iOS 26, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }
}
