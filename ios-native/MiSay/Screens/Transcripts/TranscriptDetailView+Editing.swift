import SwiftUI

/// E2 改字自動存、整理這篇、複製。2026-11-07 從詳情檔搬出來，讓它留在 300 行內。
/// 2026-11-08 米：重新潤飾拿掉（會蓋掉改好的字）；整理只給還沒有文字稿的那篇，沒有東西會被蓋。
extension TranscriptDetailView {
    func copy() {
        guard !currentText.isEmpty else {
            return
        }
        DraftPasteboard.copy(currentText)
        copyCount += 1
        showsCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            showsCopied = false
        }
    }

    func scheduleAutosave() {
        // 整理中（含從錄音重新轉錄）不存：會拿舊的那份蓋掉流水剛存的新口語稿。
        guard !isPolishing, transcript.draftText != nil, draftEdit != transcript.draftText else {
            return
        }
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.autosaveDelaySeconds))
            guard !Task.isCancelled else {
                return
            }
            flushAutosave()
        }
    }

    /// 存不進去只能大聲：用狀態條講。畫面上的字不會丟（還在編輯框裡）。
    /// 只動 `draftText`，`originalDraft` 留著給之後比對「改了哪裡」。
    func flushAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard transcript.draftText != nil, draftEdit != transcript.draftText else {
            return
        }
        do {
            try saveDraftEdit()
            saveFailed = false
        } catch {
            polishFailed = false
            saveFailed = true
        }
    }

    /// 照存檔裡最新的那份改：標題、補錄、學到哪都可能是別人剛寫的，手上的不蓋過去。
    /// 已經在垃圾桶的不存，免得又回到清單；存檔裡找不到（壞檔被搬走）就存手上的，不掉字。
    private func saveDraftEdit() throws {
        undoDiscard()
        let store = TranscriptStore()
        let stored = try store.load(id: transcript.id)
        let isInTrash = try stored == nil && store.trashedIDs().contains(transcript.id)
        guard !isInTrash else {
            throw RewriteFailure.transcriptGone
        }
        var updated = stored ?? transcript
        // 離開這頁之後才送來的字：存檔可能已經被流水接過錄音，那份先留一版，不會少字。
        let wasReplaced = updated.draftText != transcript.draftText
        // 新文稿寫過又全刪也留一版：離開時整篇進垃圾桶，撿得回剛寫的字。
        let isClearing = openedBlank && Transcript.isBlank(draftEdit)
        // 這次打開第一次存、或連著改超過十分鐘：先把存檔裡那份（改之前的樣子）留一版。
        let keepsVersion = isVersionDue || wasReplaced || isClearing
        if keepsVersion {
            updated.keepVersion()
        }
        updated.draftText = draftEdit
        updated.updatedAt = Date()
        try store.save(updated)
        transcript = updated
        if keepsVersion {
            markVersionKept()
        }
    }

    /// 「整理這篇」：只有還沒有文字稿的篇會出現，所以直接存回同一篇。
    /// 走整理流水的分塊潤飾（S2-3）：長稿不會一次送整篇超時；做到一半失敗，下次從下一塊接著做。
    func polishThis() {
        guard transcript.draftText == nil else {
            return
        }
        let source = transcript
        runPolish { await queue.retryPolish(source) }
    }

    /// S2-5「⋯ → 錄音與原稿 → 從錄音重新轉錄」：確認框按了重新轉錄才會叫。
    func retranscribe() {
        flushAutosave()
        isEditing = false
        let source = transcript
        runPolish { await queue.retranscribe(source) }
    }

    private func runPolish(_ work: @escaping @MainActor () async -> TranscriptionQueue.Outcome?) {
        polishFailed = false
        isPolishing = true
        polishTask = Task { @MainActor in
            let outcome = await work()
            isPolishing = false
            // 使用者自己按取消，不跳訊息（詞彙表語氣規則）；做好的塊流水已經存了。
            guard !Task.isCancelled else {
                return
            }
            apply(outcome)
            queue.mergeWaiting(into: transcript.id)
        }
    }

    private func apply(_ outcome: TranscriptionQueue.Outcome?) {
        switch outcome {
        case let .finished(updated):
            transcript = updated
            draftEdit = updated.draftText ?? ""
        case let .polishFailed(updated, _), let .draftNotSaved(updated):
            transcript = updated
            polishFailed = true
        case nil:
            break
        case .noAPIKey, .transcriptionFailed, .storageFailed, .recordingUnreadable,
             .recordingNotDeleted:
            polishFailed = true
        }
    }

    func cancelPolish() {
        polishTask?.cancel()
        polishTask = nil
        isPolishing = false
    }
}
