import SwiftUI

/// 懸浮在底部的膠囊分頁列（2026-11-26 米 QC-0014：原生的太低，對照番茄帳改成自畫的）。
/// 照 domy：白膠囊、第 2 級陰影，選中那格淡金底、深金字。系統分頁列由 `RootTabView` 藏起來，
/// 疊在最上層、不跟鍵盤走、每頁讓出高度也在那邊（準則 4-2 四件事）。
struct FloatingTabBar: View {
    @Binding var page: RootTabView.Page

    private struct Tab: Identifiable {
        let page: RootTabView.Page
        let title: String
        let systemImage: String
        var id: RootTabView.Page {
            page
        }
    }

    private let tabs = [
        Tab(page: .transcripts, title: "文字稿", systemImage: "doc.text"),
        Tab(page: .home, title: "錄音", systemImage: "mic"),
        Tab(page: .settings, title: "設定", systemImage: "gearshape"),
    ]

    var body: some View {
        HStack(spacing: Token.Space.xs) {
            ForEach(tabs) { tab in
                button(tab)
            }
        }
        .padding(Token.Shape.tabBarInset)
        .frame(width: Token.Shape.tabBarWidth, height: Token.Shape.tabBar)
        .background { plate }
        .padding(.bottom, Token.Shape.tabBarBottom)
        .sensoryFeedback(.selection, trigger: page)
    }

    private func button(_ tab: Tab) -> some View {
        let isOn = tab.page == page
        return Button {
            page = tab.page
        } label: {
            VStack(spacing: .zero) {
                Image(systemName: isOn ? tab.systemImage + ".fill" : tab.systemImage)
                    .font(Token.Fonts.icon)
                    .imageScale(.small)
                Text(tab.title)
                    .font(Token.Fonts.footnote)
                    .fontWeight(isOn ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isOn ? Token.Colors.link : Token.Colors.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isOn ? Token.Colors.accentSoft : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    /// 影子只掛在膠囊底上，不讓圖示和字也跟著算影子。
    private var plate: some View {
        Capsule()
            .fill(Token.Colors.rowBackground)
            .overlay {
                Capsule().strokeBorder(Token.Colors.separator, lineWidth: Token.Shape.hairline)
            }
            .shadow(
                color: Token.Colors.shadow.opacity(Token.Elevation.tabBarShadow.opacity),
                radius: Token.Elevation.tabBarShadow.radius,
                y: Token.Elevation.tabBarShadow.y
            )
    }
}
