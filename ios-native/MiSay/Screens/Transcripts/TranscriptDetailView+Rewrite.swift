import SwiftUI

/// W1「⋯ → 改寫成其他格式」：送出、存成新的一篇、以前的改寫稿拿來編輯或刪掉、失敗翻成人話。
/// Y5：改寫好的是自己的一篇，這篇不動；怎麼打開在 `TranscriptDetailView+Derived`。一次只改寫一種。
extension TranscriptDetailView {
    enum RewriteFailure: Error {
        /// 改寫中這篇被刪了：不存，免得把刪掉的篇又存回來。
        case transcriptGone
    }

    var rewritesSheet: some View {
        RewritesSheet(
            derived: derived.transcripts,
            rewrites: transcript.rewrites ?? [],
            rewritingKind: rewritingKind,
            failure: rewriteFailure,
            instruction: $derived.instruction,
            onRewrite: startRewrite,
            onCancel: cancelRewrite,
            onOpen: openRelated,
            onDeleteDerived: deleteRelated,
            onEdit: editRewrite,
            onDelete: deleteRewrite
        )
    }

    /// 自己一篇的加上以前存的。
    var rewriteCount: Int {
        derived.transcripts.count + (transcript.rewrites?.count ?? 0)
    }

    /// 改寫稿在別頁可能改過、刪過，打開前重讀。上次沒成的原因照舊留著（收起來才失敗的要看得到）。
    func openRewrites() {
        flushTitle()
        loadDerived()
        showsRewrites = true
    }

    private static let loadFailureNote = "改寫好的那幾篇讀不到，關掉這頁再打開一次。"

    private func loadDerived() {
        do {
            let stored = try TranscriptStore().loadAll().transcripts
            derived.refresh(sourceID: transcript.id, from: stored)
            if rewriteFailure == Self.loadFailureNote {
                rewriteFailure = nil
            }
        } catch {
            rewriteFailure = Self.loadFailureNote
        }
    }

    /// 「改寫成其他格式…」；改寫過就帶份數，不用點進去就知道裡面有東西。
    static func rewriteMenuTitle(copies: Int) -> String {
        copies > 0 ? "改寫成其他格式（\(copies) 份）" : "改寫成其他格式…"
    }

    /// 從現在畫面上的字出發（有文字稿就是改過的文字稿）。太長不送：一次改寫整篇會被截斷，半篇不存。
    func startRewrite(_ kind: RewriteKind, instruction: String?) {
        guard rewritingKind == nil, !isPolishing else {
            return
        }
        flushAutosave()
        let source = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            rewriteFailure = "這篇沒有字可以改寫。"
            return
        }
        guard source.count <= RewriteKind.maxSourceCharacters else {
            rewriteFailure = "這篇超過 3 萬字，一次改寫會被截斷，所以沒有送出去。"
            return
        }
        rewriteFailure = nil
        rewritingKind = kind
        rewriteTask = Task { @MainActor in
            await runRewrite(source: source, kind: kind, instruction: instruction)
        }
    }

    /// 被停掉的那次不碰狀態：停掉後馬上按另一種，新的那次已經在用這兩個欄位了。
    /// 使用者自己按停止，也不跳訊息（詞彙表語氣規則）。
    private func runRewrite(source: String, kind: RewriteKind, instruction: String?) async {
        let model = AppSettings.shared.polishModel
        do {
            let text = try await Polisher().rewrite(
                text: source,
                kind: kind,
                model: model,
                vocabulary: AppSettings.shared.vocabulary,
                instruction: instruction
            )
            guard !Task.isCancelled else {
                return
            }
            finishRewrite()
            let rewrite = TranscriptRewrite(
                kind: kind.rawValue,
                text: text,
                model: model,
                instruction: instruction
            )
            let rewritten = try saveAsTranscript(rewrite)
            loadDerived()
            showRewritten(rewritten, kind: kind)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            finishRewrite()
            let message = Self.rewriteFailureMessage(error)
            rewriteFailure = message
            if !showsRewrites {
                showNote(message)
            }
        }
    }

    /// 改寫那張頁還開著就是在等這份，收起來直接打開；收起來了就講一聲。
    private func showRewritten(_ rewritten: Transcript, kind: RewriteKind) {
        if showsRewrites {
            openRelated(rewritten)
        } else {
            showNote("改寫好了：\(kind.title)，在「⋯ → 改寫成其他格式」裡。")
        }
    }

    /// 原篇照存檔裡的看：改寫中被刪掉、進了垃圾桶的不存。
    /// 編號跟著那份改寫走：上次存好了但舊的沒拿掉，再按一次是同一篇，不會蓋掉改過的字、也不會多一篇。
    private func saveAsTranscript(_ rewrite: TranscriptRewrite) throws -> Transcript {
        let store = TranscriptStore()
        if let saved = try store.load(id: rewrite.id), saved.trashedAt == nil {
            return saved
        }
        guard let source = try store.load(id: transcript.id), source.trashedAt == nil else {
            throw RewriteFailure.transcriptGone
        }
        let rewritten = Transcript.derived(from: source, rewrite: rewrite)
        try store.save(rewritten)
        return rewritten
    }

    /// 以前的改寫稿「拿來編輯」：新的一篇存成功，才從這篇底下拿掉舊的。沒成回要講的話。
    private func editRewrite(_ rewrite: TranscriptRewrite) -> String? {
        do {
            let rewritten = try saveAsTranscript(rewrite)
            loadDerived()
            do {
                try updateStored { $0.removeRewrite(id: rewrite.id) }
            } catch {
                return "新的一篇存好了，只是舊的這份沒拿掉。再按一次試試。"
            }
            openRelated(rewritten)
            return nil
        } catch {
            return "沒存成新的一篇，這份還在。再按一次試試。"
        }
    }

    private func finishRewrite() {
        rewritingKind = nil
        rewriteTask = nil
    }

    func cancelRewrite() {
        rewriteTask?.cancel()
        rewriteTask = nil
        rewritingKind = nil
    }

    func deleteRewrite(_ rewrite: TranscriptRewrite) {
        do {
            try updateStored { $0.removeRewrite(id: rewrite.id) }
        } catch {
            rewriteFailure = "刪不掉，再試一次。"
        }
    }

    /// 錯誤第二句講原因，跟完成面板同一套說法（`RecordingResultView.failedStatus`）。
    static func rewriteFailureMessage(_ error: Error) -> String {
        switch error {
        case let failure as OpenAIClient.Failure:
            rewriteFailureMessage(for: failure)
        case Polisher.Failure.incomplete:
            "改寫到一半被截掉了，沒有存。"
        case Polisher.Failure.emptyDraft, Polisher.Failure.malformedResponse:
            "OpenAI 回來的不是一篇稿子，再按一次試試。"
        case RewriteFailure.transcriptGone:
            "這篇已經刪掉了，改寫的沒有存。"
        default:
            "改寫好了但存不進去，手機空間可能不夠。"
        }
    }

    /// 跟上面拆開：兩層 switch 寫在一起，SwiftLint 的複雜度會超過 10。
    private static func rewriteFailureMessage(for failure: OpenAIClient.Failure) -> String {
        switch failure {
        case .missingAPIKey:
            "還沒設定 OpenAI 金鑰，到設定貼上。"
        case .invalidAPIKey:
            "金鑰沒有用，到設定換一把。"
        case .quotaExhausted:
            "OpenAI 說額度用完了，到 OpenAI 後台處理。"
        case .timedOut, .transport:
            "現在沒有網路，連上後再按一次。"
        case .rateLimited, .serverError:
            "OpenAI 現在忙，等一下再按一次。"
        case .rejected, .malformedResponse, .invalidPath:
            "OpenAI 沒有收下，再按一次試試。"
        }
    }

    /// 先把手上改的字存掉，再拿存檔裡最新的那份改了存：這頁開著時，接著錄、別處整理完都可能讓存檔比手上的新，
    /// 拿手上的存會把那些蓋掉。存檔裡沒有這篇就是被刪了（在垃圾桶），不存。
    func updateStored(_ change: (inout Transcript) -> Void) throws {
        flushAutosave()
        let keepsHand = hasUnsavedDraft
        let store = TranscriptStore()
        guard var updated = try store.load(id: transcript.id), updated.trashedAt == nil else {
            throw RewriteFailure.transcriptGone
        }
        change(&updated)
        try store.save(updated)
        transcript = updated
        // 手上的字剛才沒存進去：留在編輯框裡，不拿存檔的蓋掉。
        if !keepsHand {
            draftEdit = updated.draftText ?? ""
        }
    }
}
