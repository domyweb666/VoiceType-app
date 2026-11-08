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
        // S4-3：點了「文字稿好了」通知。冷啟動時 id 在畫面出來前就到了，onChange 看不到，要 onAppear 補。
        .onAppear { openFromNotification(NotificationRouter.shared.openTranscriptID) }
        .onChange(of: NotificationRouter.shared.openTranscriptID) { _, id in
            openFromNotification(id)
        }
    }

    private func openFromNotification(_ id: UUID?) {
        guard let id else {
            return
        }
        NotificationRouter.shared.openTranscriptID = nil
        // 那篇讀不到（剛好被刪了）就停在原本的分頁，什麼都不做。
        let transcripts = (try? TranscriptStore().loadAll().transcripts) ?? []
        guard let transcript = transcripts.first(where: { $0.id == id }) else {
            return
        }
        open(transcript)
    }

    private func open(_ transcript: Transcript) {
        openingTranscript = transcript
        page = .transcripts
    }
}
