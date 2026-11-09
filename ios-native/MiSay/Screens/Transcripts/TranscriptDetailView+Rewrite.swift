import SwiftUI

/// W1「⋯ → 改寫成其他格式」：送出、存回這篇、刪一份、失敗翻成人話。
/// 改寫好的存成這篇底下的另一份（`Transcript.rewrites`），文字稿不動。一次只改寫一種。
extension TranscriptDetailView {
    enum RewriteFailure: Error {
        /// 改寫中這篇被刪了：不存，免得把刪掉的篇又存回來。
        case transcriptGone
    }

    var rewritesSheet: some View {
        RewritesSheet(
            rewrites: transcript.rewrites ?? [],
            rewritingKind: rewritingKind,
            failure: rewriteFailure,
            onRewrite: startRewrite,
            onCancel: cancelRewrite,
            onDelete: deleteRewrite
        )
    }

    /// 「改寫成其他格式…」；改寫過就帶份數，不用點進去就知道裡面有東西。
    static func rewriteMenuTitle(copies: Int) -> String {
        copies > 0 ? "改寫成其他格式（\(copies) 份）" : "改寫成其他格式…"
    }

    /// 從現在畫面上的字出發（有文字稿就是改過的文字稿）。太長不送：一次改寫整篇會被截斷，半篇不存。
    func startRewrite(_ kind: RewriteKind) {
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
            await runRewrite(source: source, kind: kind)
        }
    }

    /// 被停掉的那次不碰狀態：停掉後馬上按另一種，新的那次已經在用這兩個欄位了。
    /// 使用者自己按停止，也不跳訊息（詞彙表語氣規則）。
    private func runRewrite(source: String, kind: RewriteKind) async {
        let model = AppSettings.shared.polishModel
        do {
            let text = try await Polisher().rewrite(
                text: source,
                kind: kind,
                model: model,
                vocabulary: AppSettings.shared.vocabulary
            )
            guard !Task.isCancelled else {
                return
            }
            finishRewrite()
            let rewrite = TranscriptRewrite(kind: kind.rawValue, text: text, model: model)
            try updateStored { $0.addRewrite(rewrite) }
            if !showsRewrites {
                showNote("改寫好了：\(kind.title)，在「⋯ → 改寫成其他格式」裡。")
            }
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
        case .invalidAPIKey, .missingAPIKey:
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
    /// 拿手上的存會把那些蓋掉。存檔裡沒有這篇就是被刪了，不存。
    func updateStored(_ change: (inout Transcript) -> Void) throws {
        flushAutosave()
        let stored = try TranscriptStore().loadAll().transcripts.first { $0.id == transcript.id }
        guard var updated = stored else {
            throw RewriteFailure.transcriptGone
        }
        change(&updated)
        try TranscriptStore().save(updated)
        transcript = updated
        draftEdit = updated.draftText ?? ""
    }
}
