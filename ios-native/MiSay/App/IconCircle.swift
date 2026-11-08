import SwiftUI

/// 面板頂上那個圖示。讀屏不唸它，字已經講了。
/// 2026-11-08 米選原生：拿掉凹槽圓底，改成系統的分層上色大圖示（跟系統空狀態、提示框同一種）。
/// 名字沒改，呼叫的地方不用動。
struct IconCircle: View {
    let systemName: String
    var tint = Token.Colors.textPrimary

    var body: some View {
        Image(systemName: systemName)
            .font(Token.Fonts.largeTitle)
            .imageScale(.large)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(minWidth: Token.Shape.iconCircle, minHeight: Token.Shape.iconCircle)
            .accessibilityHidden(true)
    }
}
