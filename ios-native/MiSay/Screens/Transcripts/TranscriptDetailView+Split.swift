import SwiftUI

/// 「⋯ → 這趟講了幾件事」（片 J3）：送出、收結果、存成幾篇、失敗翻成人話。
/// 按了才送；結果不存，離開這頁就沒了。存的字從文字稿照搬，這篇不動。
extension TranscriptDetailView {
    /// 還沒有文字稿的篇沒有稿可以拆。
    @ViewBuilder
    var splitMenuItem: some View {
        if transcript.draftText != nil {
            Button(action: openSplit) {
                Label("這趟講了幾件事", systemImage: "scissors")
            }
            .disabled(isPolishing || currentText.isEmpty)
        }
    }

    /// 包在這裡，主檔的 body 不用再長。收好了才開點的那篇，跟改寫那張頁一樣。
    func withSplit(_ content: some View) -> some View {
        content
            .sheet(isPresented: $showsSplit, onDismiss: openPendingRelated) { splitSheet }
    }

    private var splitSheet: some View {
        SplitSheet(
            session: $split,
            text: draftEdit,
            pieces: derived.pieces,
            canOpen: rewritingKind == nil && !split.isRunning,
            onStart: startSplit,
            onCancel: cancelSplit,
            onSave: saveSplit,
            onOpen: openRelated
        )
    }

    private static let loadFailureNote = "拆出來的那幾篇讀不到，關掉這頁再打開一次。"

    /// 拆出來的在別頁可能改過、刪過，打開前重讀。
    private func openSplit() {
        loadPieces()
        showsSplit = true
    }

    private func loadPieces() {
        do {
            let stored = try TranscriptStore().loadAll().transcripts
            derived.refresh(sourceID: transcript.id, from: stored)
            if split.failure == Self.loadFailureNote {
                split.failure = nil
            }
        } catch {
            split.failure = Self.loadFailureNote
        }
    }

    private func startSplit() {
        guard !split.isRunning, !isPolishing else {
            return
        }
        let source = draftEdit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            split.failure = "這篇沒有字可以拆。"
            return
        }
        guard source.count <= RewriteKind.maxSourceCharacters else {
            split.failure = "這篇超過 3 萬字，太長了，沒有送出去。"
            return
        }
        split.failure = nil
        split.isRunning = true
        split.task = Task { @MainActor in
            await runSplit(source: source)
        }
    }

    /// 被停掉的那次不碰狀態：停掉後馬上再按，新的那次已經在用了。
    private func runSplit(source: String) async {
        do {
            let result = try await Polisher().splitTopics(
                text: source,
                model: AppSettings.shared.polishModel,
                vocabulary: AppSettings.shared.vocabulary
            )
            guard !Task.isCancelled else {
                return
            }
            finishSplit()
            loadPieces()
            split.show(result, from: source, hasEarlierPieces: !derived.pieces.isEmpty)
            if !showsSplit {
                showNote("分好了，在「⋯ → 這趟講了幾件事」裡。")
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }
            finishSplit()
            let message = Self.splitFailureMessage(error)
            split.failure = message
            if !showsSplit {
                showNote(message)
            }
        }
    }

    private func finishSplit() {
        split.isRunning = false
        split.task = nil
    }

    func cancelSplit() {
        split.task?.cancel()
        finishSplit()
    }

    private func saveSplit() {
        let topics = split.chosenTopics
        do {
            let failedIDs = try TranscriptStore().saveSplit(topics, of: transcript.id)
            split.recordSave(of: topics, failedIDs: failedIDs)
            loadPieces()
        } catch TranscriptStore.Failure.notFound {
            split.saveFailure = "這篇已經刪掉了，所以沒有存。"
        } catch {
            split.saveFailure = "這篇的存檔讀不到，所以沒有存。再按一次試試。"
        }
    }

    /// 網路與金鑰那些跟改寫同一套說法；存檔的失敗在 `saveSplit`。
    static func splitFailureMessage(_ error: Error) -> String {
        switch error {
        case is OpenAIClient.Failure:
            rewriteFailureMessage(error)
        case Polisher.Failure.incomplete:
            "回到一半被截掉了，再按一次試試。"
        case is Polisher.Failure:
            "OpenAI 回來的看不懂，再按一次試試。"
        default:
            "沒有分成，再按一次試試。"
        }
    }
}
