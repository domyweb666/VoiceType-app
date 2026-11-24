import SwiftUI

/// 「文字稿」推入頁（片 D7、E3 復原、E6 搜尋）：歷史篇最新在上，點一列開詳情。
/// 讀不到的篇數照 PRD 說「原檔已保留」，不自己清空。
/// 片 D6「打開這篇」從錄音面板進來時先推到那一篇；返回落在清單，刪除照樣走「已刪除・復原」。
/// 2026-11-07 統一風格：分「今天／本週／更早」、列是日期在上兩行預覽、空清單有玉米、狀態條統一。
/// 2026-11-14 照 domy-design：列本來就是 domy 的 ListRow（日期在上、內容兩行），顏色與圓角跟著代號換。
/// W6：照標籤篩、選幾篇合併成一篇，在 `TranscriptListView+Organize.swift`。
/// 2026-11-24：照最後改的時間排、分草稿與已發布（`+Filter`）；刪掉的進垃圾桶（`+Deletion`）。
struct TranscriptListView: View {
    static let todayTitle = "今天"
    static let weekTitle = "本週"
    static let olderTitle = "更早"

    /// 「已刪除・復原」留多久（PRD：5 秒內可復原）。
    static let undoWindowSeconds: Double = 5

    private let openingTranscript: Transcript?
    private let onOpenHome: () -> Void
    @Environment(TranscriptionQueue.self) var queue
    @State var openedTranscript: Transcript?
    @State private var hasOpenedInitialTranscript = false
    @State var transcripts: [Transcript] = []
    @State var unreadableCount = 0
    @State private var loadFailed = false
    @State var deleteFailed = false
    @State var query = ""
    @State var pendingDeletion: Transcript?
    @State var deletionTask: Task<Void, Never>?
    @State var deleteCount = 0
    /// 2026-11-24：只看草稿或已發布；nil 是全部。
    @State var publishFilter: PublishFilter?
    @State var publishFailed = false
    /// 2026-11-24：垃圾桶裡有幾篇、垃圾桶那頁開著沒。
    @State var trashCount = 0
    @State var showsTrash = false
    /// W6：只看這個標籤的篇；nil 是全部。
    @State var selectedTag: String?
    /// W6：選取模式，點列是勾起來，不是打開。
    @State var isSelecting = false
    @State var selectedIDs: Set<UUID> = []
    @State var mergeFailed = false
    /// 2026-11-15：新文稿存不進去。
    @State var newDraftFailed = false

    init(opening transcript: Transcript? = nil, onOpenHome: @escaping () -> Void = {}) {
        openingTranscript = transcript
        self.onOpenHome = onOpenHome
    }

    var body: some View {
        List {
            if unreadableCount > 0 {
                unreadableBanner
            }
            ForEach(groups, id: \.title) { group in
                Section {
                    ForEach(group.transcripts) { transcript in
                        let showsDate = group.title != Self.todayTitle
                        if isSelecting {
                            selectableRow(transcript, showsDate: showsDate)
                        } else {
                            openableRow(transcript, showsDate: showsDate)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    publishButton(transcript)
                                }
                        }
                    }
                    .listRowBackground(Token.Colors.rowBackground)
                } header: {
                    Text(group.title)
                        .font(Token.Fonts.sectionTitle)
                        .foregroundStyle(Token.Colors.textPrimary)
                        .textCase(nil)
                }
            }
            trashRow
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .searchable(text: $query, prompt: "搜尋文字稿")
        .overlay { emptyOverlay }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                mergeBar
            } else {
                undoBanner
            }
        }
        .sensoryFeedback(Token.Haptics.deleted, trigger: deleteCount)
        .navigationTitle(pageTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { newDraftButton }
            ToolbarItem(placement: .topBarTrailing) { ImportAudioButton() }
            organizeToolbar
        }
        .navigationDestination(item: $openedTranscript) { detail(of: $0) }
        .navigationDestination(isPresented: $showsTrash) { TrashView(onChange: reload) }
        .task {
            reload()
            openInitialTranscriptOnce()
        }
        .onDisappear { commitDeletionNow() }
        .alert("新文稿沒開成，再按一次。", isPresented: $newDraftFailed) {
            Button("好") {}
        }
        .alert("沒改成，這篇還是原來的樣子。", isPresented: $publishFailed) {
            Button("好") {}
        }
    }

    private func detail(of transcript: Transcript) -> some View {
        TranscriptDetailView(transcript: transcript, onDelete: softDelete, onLeave: reload)
    }

    /// `.task` 每次回到這頁都會跑，所以要記住已經推過，不然從詳情返回又被推回去。
    private func openInitialTranscriptOnce() {
        guard !hasOpenedInitialTranscript, let openingTranscript else {
            return
        }
        hasOpenedInitialTranscript = true
        openedTranscript = openingTranscript
    }

    func reload() {
        do {
            let result = try TranscriptStore().loadAll()
            transcripts = Self.listOrder(result.transcripts)
            unreadableCount = result.unreadableCount
            loadFailed = false
            reloadTrashCount()
        } catch {
            loadFailed = true
        }
    }
}

/// 讀不到的橫幅與空狀態。列在 `TranscriptListView+Organize.swift`。
private extension TranscriptListView {
    var unreadableBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: Token.Space.s) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Token.Colors.danger)
                .accessibilityHidden(true)
            Text("有 \(unreadableCount) 篇文字稿讀不到，原檔已保留。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textPrimary)
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    @ViewBuilder
    var emptyOverlay: some View {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // 2026-11-08 米選原生：空狀態都用系統的 ContentUnavailableView（圖示、標題、說明、按鈕）。
        // 2026-11-14 照 domy 的 EmptyState：下一步那顆是小的主要按鈕（這頁沒有別的主要按鈕）。
        // 不用系統內建的搜尋空狀態：它的字跟著 App 語系走，可能跑出英文。
        if visibleTranscripts.isEmpty, !keyword.isEmpty {
            ContentUnavailableView {
                Label("沒有找到", systemImage: "magnifyingglass")
            } description: {
                Text("沒有包含『\(keyword)』的文字稿")
            } actions: {
                Button("清除搜尋") {
                    query = ""
                }
                .buttonStyle(PrimaryButtonStyle(isCompact: true))
            }
        } else if visibleTranscripts.isEmpty, let selectedTag {
            ContentUnavailableView {
                Label("沒有這個標籤的文字稿", systemImage: "tag")
            } description: {
                Text("「\(selectedTag)」這個標籤現在沒有掛在任何一篇上。")
            } actions: {
                showAllButton
            }
        } else if visibleTranscripts.isEmpty, let publishFilter {
            ContentUnavailableView {
                Label(publishFilter.emptyTitle, systemImage: publishFilter.emptyImage)
            } description: {
                Text(publishFilter.emptyNote)
            } actions: {
                showAllButton
            }
        } else if visibleTranscripts.isEmpty, unreadableCount == 0 {
            emptyState
        }
    }

    var showAllButton: some View {
        Button("看全部") {
            selectedTag = nil
            publishFilter = nil
        }
        .buttonStyle(PrimaryButtonStyle(isCompact: true))
    }

    /// 玉米只在這裡出現（使用規則第 3 條），當系統空狀態的圖。讀不到時不裝可愛，只講讀取失敗。
    @ViewBuilder
    var emptyState: some View {
        if loadFailed {
            ContentUnavailableView("文字稿讀取失敗", systemImage: "exclamationmark.triangle")
        } else {
            ContentUnavailableView {
                Label {
                    Text("還沒有文字稿")
                } icon: {
                    CornIllustration()
                }
            } description: {
                Text("到「錄音」分頁按中間的鈕，說一段話。說完的字會排在這裡，最新的在最上面。")
            } actions: {
                Button("去錄音") {
                    onOpenHome()
                }
                .buttonStyle(PrimaryButtonStyle(isCompact: true))
                if trashCount > 0 {
                    Button(Self.trashTitle(count: trashCount), action: openTrash)
                        .buttonStyle(TextButtonStyle())
                }
            }
        }
    }
}
