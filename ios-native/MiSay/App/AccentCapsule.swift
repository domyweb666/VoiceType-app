import SwiftUI

/// 淡金膠囊（domy-design 設定列的 picker、錄音畫面的「錄音中」）：淡金底、深金字、34 高。
/// 只管長相；能不能按由外面包的 `Menu` 或 `Button` 決定。
struct AccentCapsule<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: Token.Space.s) {
            content
        }
        .font(Token.Fonts.callout)
        .foregroundStyle(Token.Colors.link)
        .padding(.horizontal, Token.Space.m)
        .frame(minHeight: Token.Shape.pickerHeight)
        .background(Token.Colors.accentSoft, in: Capsule())
    }
}
