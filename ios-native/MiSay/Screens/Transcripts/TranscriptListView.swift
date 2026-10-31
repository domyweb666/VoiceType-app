import SwiftUI

/// 「文字稿」推入頁（片 D7、E3 復原、E6 搜尋）：歷史篇最新在上，點一列開詳情。
/// 讀不到的篇數照 PRD 說「原檔已保留」，不自己清空。
/// 片 D6「打開這篇」從錄音面板進來時先推到那一篇；返回落在清單，刪除照樣走「已刪除・復原」。
struct TranscriptListView: View {
    private let openingTranscript: Transcript?
    @State private var openedTranscript: Transcript?
    @State private var hasOpenedInitialTranscript = false
    @State private var transcripts: [Transcript] = []
    @State private var unreadableCount = 0
    @State private var loadFailed = false
    @State private var query = ""
    @State private var pendingDeletion: Transcript?
    @State private var deletionTask: Task<Void, Never>?

    /// 「已刪除・復原」留多久（PRD：5 秒內可復原）。
    static let undoWindowSeconds: Double = 5

    init(opening transcript: Transcript? = nil) {
        openingTranscript = transcript
    }

    var body: some View {
        List {
            if unreadableCount > 0 {
                unreadableBanner
            }
            ForEach(visibleTranscripts) { transcript in
                NavigationLink {
                    TranscriptDetailView(transcript: transcript, onDelete: softDelete)
                } label: {
                    row(transcript)
                }
                .listRowBackground(Token.Colors.rowBackground)
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

    private func row(_ transcript: Transcript) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text(Self.subtitle(for: transcript))
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
            Text(transcript.displayText)
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineLimit(2)
        }
    }

    private var unreadableBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: Token.Space.s) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Token.Colors.danger)
                .accessibilityHidden(true)
            Text("有 \(unreadableCount) 篇歷史讀不到，原檔已保留。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textPrimary)
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    @ViewBuilder
    private var emptyOverlay: some View {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if visibleTranscripts.isEmpty, !keyword.isEmpty {
            VStack(spacing: Token.Space.m) {
                Text("沒有包含『\(keyword)』的文字稿")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                Button("清除搜尋") { query = "" }
                    .font(Token.Fonts.body)
                    .tint(Token.Colors.link)
            }
            .padding(.horizontal, Token.Space.xl)
        } else if visibleTranscripts.isEmpty, unreadableCount == 0 {
            Text(loadFailed ? "文字稿讀取失敗。" : "還沒有文字稿。回首頁按中間的玉米，說一段話。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Token.Space.xl)
        }
    }

    /// 底部「已刪除・復原」（詞彙表）。5 秒內按復原，那篇回到清單原位（照時間排，位置自然回來）。
    @ViewBuilder
    private var undoBanner: some View {
        if pendingDeletion != nil {
            HStack {
                Text("已刪除")
                    .font(Token.Fonts.body)
                    .foregroundStyle(Token.Colors.textPrimary)
                Spacer()
                Button("復原") { undoDeletion() }
                    .font(Token.Fonts.rowTitle)
                    .tint(Token.Colors.link)
            }
            .padding(.horizontal, Token.Space.l)
            .padding(.vertical, Token.Space.m)
            .background(
                Token.Colors.rowBackground,
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow)
            )
            .padding(.horizontal, Token.Space.l)
            .padding(.bottom, Token.Space.s)
        }
    }

    /// 「10 月 31 日 14:32・3 分 48 秒」（線框詳情頁的副標）。
    static func subtitle(for transcript: Transcript) -> String {
        let date = transcript.createdAt.formatted(date: .abbreviated, time: .shortened)
        return date + "・" + RecordingSheetView.formatSpoken(transcript.durationSeconds)
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

    // MARK: - E3 刪除與復原

    /// 先從畫面拿掉、5 秒後才真的刪檔；期間按「復原」就放回去。
    private func softDelete(_ transcript: Transcript) {
        commitDeletionNow()
        pendingDeletion = transcript
        deletionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.undoWindowSeconds))
            guard !Task.isCancelled else {
                return
            }
            commitDeletionNow()
        }
    }

    private func undoDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        pendingDeletion = nil
    }

    private func commitDeletionNow() {
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
            // 刪不掉就留著：下次 reload 它還在清單裡，比默默消失誠實。
            loadFailed = true
        }
    }
}
