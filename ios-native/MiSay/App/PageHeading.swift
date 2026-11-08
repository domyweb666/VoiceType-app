import SwiftUI

/// 左右滑那三頁的大標，放在清單第一列自己畫。
/// 系統的大標放在 `TabView(.page)` 裡會貼齊螢幕左緣、字被切掉（2026-11-08 米真機截圖「文字稿」「設定」），
/// 所以系統那條只留空的 inline 列給搜尋與返回用，大標改由這裡畫，左緣對齊卡片。
struct PageHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Token.Fonts.largeTitle)
            .foregroundStyle(Token.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

extension View {
    /// 系統標題列留著（搜尋框、推入頁的返回要用），但不顯示字；字交給 `PageHeading`。
    /// 推入的頁跟著變 inline，標題置中，不會再碰到貼左緣的問題。
    func pageTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                }
            }
    }
}
