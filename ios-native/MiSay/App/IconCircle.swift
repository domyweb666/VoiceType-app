import SwiftUI

/// 面板頂上那個圖示。讀屏不唸它，字已經講了。
/// 2026-11-14 照 domy-design 的空狀態圖示：64 的淡金圓底，裡面是金棕圖示。失敗用 `failure`（淡紅底紅圖示）。
struct IconCircle: View {
    static let failure = IconCircle(
        systemName: "exclamationmark.circle.fill",
        tint: Token.Colors.danger,
        fill: Token.Colors.dangerSoft
    )

    let systemName: String
    var tint = Token.Colors.accent
    var fill = Token.Colors.accentSoft

    var body: some View {
        Image(systemName: systemName)
            .font(Token.Fonts.icon)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: Token.Shape.iconCircle, height: Token.Shape.iconCircle)
            .background(fill, in: Circle())
            .accessibilityHidden(true)
    }
}
