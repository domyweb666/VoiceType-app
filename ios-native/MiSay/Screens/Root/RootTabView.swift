import SwiftUI

/// 三個分頁：左「文字稿」、中「錄音」、右「設定」，打開停在中間。每個分頁有自己的 NavigationStack。
/// 2026-11-02 米選左右滑＋頁面小點；2026-11-08 米改成原生底部分頁列（iOS 26 是浮在底部的玻璃列）。
/// 左右滑的結構讓系統大標貼左緣、錄音鈕置中不準、大標上面空一塊，換成系統分頁列這三個一起沒了。
struct RootTabView: View {
    enum Page: Hashable {
        case transcripts
        case home
        case settings
    }

    @State private var page = Page.home
    /// 錄音面板「打開這篇」要推的那一篇。換一篇就重建清單頁（`.id`），讓它照 `opening` 推進去。
    @State private var openingTranscript: Transcript?

    var body: some View {
        TabView(selection: $page) {
            NavigationStack {
                TranscriptListView(opening: openingTranscript, onOpenHome: { page = .home })
                    .id(openingTranscript?.id)
            }
            .tabItem { Label("文字稿", systemImage: "doc.text") }
            .tag(Page.transcripts)

            NavigationStack {
                HomeView(
                    isCurrentPage: page == .home,
                    onOpenTranscript: open,
                    onOpenSettings: { page = .settings }
                )
            }
            .tabItem { Label("錄音", systemImage: "mic") }
            .tag(Page.home)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
            .tag(Page.settings)
        }
        .tint(Token.Colors.link)
    }

    private func open(_ transcript: Transcript) {
        openingTranscript = transcript
        page = .transcripts
    }
}
