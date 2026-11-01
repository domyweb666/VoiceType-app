import SwiftUI

/// 三頁左右滑（2026-11-02 米：「左滑進到設定頁，右滑進到錄音紀錄頁」，參考他另一個 App 的頁面小點）。
/// 左「文字稿」、中「首頁」、右「設定」，打開停在中間。每頁有自己的 NavigationStack，清單的搜尋、
/// 設定的推頁都照舊；最上面一排小點告訴人可以左右滑，點小點也能直接換頁（不方便滑的人用）。
struct RootPagerView: View {
    enum Page: CaseIterable, Hashable {
        case transcripts
        case home
        case settings

        var title: String {
            switch self {
            case .transcripts:
                "文字稿"
            case .home:
                "首頁"
            case .settings:
                "設定"
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = Page.home
    /// 錄音面板「打開這篇」要推的那一篇。換一篇就重建清單頁（`.id`），讓它照 `opening` 推進去。
    @State private var openingTranscript: Transcript?

    var body: some View {
        TabView(selection: $page) {
            NavigationStack {
                TranscriptListView(opening: openingTranscript)
                    .id(openingTranscript?.id)
            }
            .tag(Page.transcripts)
            NavigationStack {
                HomeView(onOpenTranscript: open, onOpenSettings: { go(to: .settings) })
            }
            .tag(Page.home)
            NavigationStack {
                SettingsView()
            }
            .tag(Page.settings)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Token.Colors.groupedBackground)
        .safeAreaInset(edge: .top) { pageDots }
    }

    /// 目前那頁是拉長的膠囊，其他是圓點（照米給的參考圖）。
    private var pageDots: some View {
        HStack(spacing: Token.Space.s) {
            ForEach(Page.allCases, id: \.self) { dot in
                Button {
                    go(to: dot)
                } label: {
                    Capsule()
                        .fill(dot == page ? Token.Colors.textPrimary : Token.Colors.textSecondary)
                        .frame(
                            width: dot == page ? Token.Space.xl : Token.Space.s,
                            height: Token.Space.s
                        )
                        .frame(minHeight: Token.Shape.minTap)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dot.title)
                .accessibilityAddTraits(dot == page ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .background(Token.Colors.groupedBackground)
    }

    private func go(to target: Page) {
        withAnimation(Token.Motion.sheetRise(reduceMotion)) {
            page = target
        }
    }

    private func open(_ transcript: Transcript) {
        openingTranscript = transcript
        go(to: .transcripts)
    }
}
