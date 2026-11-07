import SwiftUI

/// 面板頂上那顆圖示圓：凹槽底、`iconCircle` 大，裡面一個系統圖示。讀屏不唸它，字已經講了。
struct IconCircle: View {
    let systemName: String
    var tint = Token.Colors.textPrimary

    var body: some View {
        Image(systemName: systemName)
            .font(Token.Fonts.icon)
            .foregroundStyle(tint)
            .frame(width: Token.Shape.iconCircle, height: Token.Shape.iconCircle)
            .background(Token.Colors.sunkenBackground, in: Circle())
            .accessibilityHidden(true)
    }
}
