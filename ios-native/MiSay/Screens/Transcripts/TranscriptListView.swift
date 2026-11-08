import SwiftUI

/// 「文字稿」推入頁（片 D7、E3 復原、E6 搜尋）：歷史篇最新在上，點一列開詳情。
/// 讀不到的篇數照 PRD 說「原檔已保留」，不自己清空。
/// 片 D6「打開這篇」從錄音面板進來時先推到那一篇；返回落在清單，刪除照樣走「已刪除・復原」。
/// 2026-11-07 統一風格：分「今天／本週／更早」、列是日期在上兩行預覽、空清單有玉米、狀態條統一。
struct TranscriptListView: View {
    /// 一組：標題與照時間排好的那幾篇。
    private struct TranscriptGroup {
        let title: String
        var transcripts: [Transcript]
    }

    static let todayTitle = "今天"
    static let weekTitle = "本週"
    static let olderTitle = "更早"

    /// 「已刪除・復原」留多久（PRD：5 秒內可復原）。
    static let undoWindowSeconds: Double = 5

    private let openingTranscript: Transcript?
    private let onOpenHome: () -> Void
    @State private var openedTranscript: Transcript?
    @State private var hasOpenedInitialTranscript = false
    @State private var transcripts: [Transcript] = []
    @State private var unreadableCount = 0
    @State private var loadFailed = false
    @State private var deleteFailed = false
    @State private var query = ""
    @State private var pendingDeletion: Transcript?
    @State private var deletionTask: Task<Void, Never>?

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
                        NavigationLink {
                            TranscriptDetailView(transcript: transcript, onDelete: softDelete)
                        } label: {
                            row(transcript, showsDate: group.title != Self.todayTitle)
                        }
                        .listRowBackground(Token.Colors.rowBackground)
                    }
                } header: {
                    Text(group.title)
                        .font(Token.Fonts.sectionTitle)
                        .foregroundStyle(Token.Colors.textPrimary)
                        .textCase(nil)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .searchable(text: $query, prompt: "搜尋文字稿")
        .overlay { emptyOverlay }
        .safeAreaInset(edge: .bottom) { undoBanner }
        .navigationTitle("文字稿")
        .navigationDestination(item: $openedTranscript) { transcript in
            TranscriptDetailView(transcript: transcript, onDelete: softDelete)
        }
        .task {
            reload()
            openInitialTranscriptOnce()
        }
        .onDisappear { commitDeletionNow() }
    }

    /// 今天、本週（同一個行事曆週）、更早。只是給人看的分組，不影響排序。
    static func groupTitle(
        for date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return todayTitle
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return weekTitle
        }
        return olderTitle
    }

    /// 「10 月 31 日 14:32・3 分 48 秒」（線框詳情頁的副標）。
    static func subtitle(for transcript: Transcript) -> String {
        let date = transcript.createdAt.formatted(date: .abbreviated, time: .shortened)
        return date + "・" + RecordingSheetView.formatSpoken(transcript.durationSeconds)
    }

    /// 「今天」那一組只講時間：「14:32・3 分 48 秒」。
    static func timeSubtitle(for transcript: Transcript) -> String {
        let time = transcript.createdAt.formatted(date: .omitted, time: .shortened)
        return time + "・" + RecordingSheetView.formatSpoken(transcript.durationSeconds)
    }

    /// 搜尋只看內容（口語稿與文字稿都算），不分大小寫。
    private var visibleTranscripts: [Transcript] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let notDeleted = transcripts.filter { $0.id != pendingDeletion?.id }
        guard !keyword.isEmpty else {
            return notDeleted
        }
        return notDeleted.filter {
            $0.rawText.localizedCaseInsensitiveContains(keyword)
                || ($0.draftText ?? "").localizedCaseInsensitiveContains(keyword)
        }
    }

    /// 照清單順序把每篇塞進它的組，組的順序跟著第一篇出現的順序（最新在上）。
    private var groups: [TranscriptGroup] {
        var groups: [TranscriptGroup] = []
        for transcript in visibleTranscripts {
            let title = Self.groupTitle(for: transcript.createdAt)
            if let index = groups.firstIndex { $0.title == title } {
                groups[index].transcripts.append(transcript)
            } else {
                groups.append(TranscriptGroup(title: title, transcripts: [transcript]))
            }
        }
        return groups
    }

    /// `.task` 每次回到這頁都會跑，所以要記住已經推過，不然從詳情返回又被推回去。
    private func openInitialTranscriptOnce() {
        guard !hasOpenedInitialTranscript, let openingTranscript else {
            return
        }
        hasOpenedInitialTranscript = true
        openedTranscript = openingTranscript
    }

    private func reload() {
        do {
            let result = try TranscriptStore().loadAll()
            transcripts = result.transcripts
            unreadableCount = result.unreadableCount
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}

/// 列、空狀態、狀態條。
private extension TranscriptListView {
    func row(_ transcript: Transcript, showsDate: Bool) -> some View {
        let subtitle = showsDate
            ? Self.subtitle(for: transcript)
            : Self.timeSubtitle(for: transcript)
        return VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text(subtitle)
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
            Text(transcript.displayText)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineLimit(2)
        }
    }

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
                .buttonStyle(TextButtonStyle())
            }
        } else if visibleTranscripts.isEmpty, unreadableCount == 0 {
            emptyState
        }
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
                .buttonStyle(TextButtonStyle())
            }
        }
    }

    /// 底部「已刪除・復原」（詞彙表）。5 秒內按復原，那篇回到清單原位（照時間排，位置自然回來）。
    @ViewBuilder
    var undoBanner: some View {
        if pendingDeletion != nil {
            StatusStrip(
                glyph: .done,
                message: "已刪除",
                actionTitle: "復原",
                action: undoDeletion,
                isFloating: true
            )
            .padding(.horizontal, Token.Space.l)
            .padding(.bottom, Token.Space.s)
        } else if deleteFailed {
            // 清單有東西時空狀態那句不會出現，刪不掉要在這裡講，不然那篇像是自己跑回來。
            StatusStrip(glyph: .failed, message: "沒刪掉，這篇還在。再刪一次看看。")
                .padding(.horizontal, Token.Space.l)
                .padding(.bottom, Token.Space.s)
        }
    }

    // MARK: - E3 刪除與復原

    /// 先從畫面拿掉、5 秒後才真的刪檔；期間按「復原」就放回去。
    func softDelete(_ transcript: Transcript) {
        commitDeletionNow()
        deleteFailed = false
        pendingDeletion = transcript
        deletionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.undoWindowSeconds))
            guard !Task.isCancelled else {
                return
            }
            commitDeletionNow()
        }
    }

    func undoDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        pendingDeletion = nil
    }

    func commitDeletionNow() {
        deletionTask?.cancel()
        deletionTask = nil
        guard let doomed = pendingDeletion else {
            return
        }
        pendingDeletion = nil
        do {
            try TranscriptStore().delete(id: doomed.id)
            transcripts.removeAll { $0.id == doomed.id }
        } catch {
            // 刪不掉就留著：它還在清單裡，並且說出來，比默默消失誠實。
            deleteFailed = true
        }
    }
}
