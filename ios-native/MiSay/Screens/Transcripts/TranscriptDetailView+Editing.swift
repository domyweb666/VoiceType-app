import SwiftUI

/// E2 改字自動存、整理這篇、複製。2026-11-07 從詳情檔搬出來，讓它留在 300 行內。
/// 2026-11-08 米：重新潤飾拿掉（會蓋掉改好的字）；整理只給還沒有文字稿的那篇，沒有東西會被蓋。
extension TranscriptDetailView {
    func copy() {
        guard !currentText.isEmpty else {
            return
        }
        UIPasteboard.general.string = currentText
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
        var updated = transcript
        updated.draftText = draftEdit
        updated.updatedAt = Date()
        do {
            try TranscriptStore().save(updated)
            transcript = updated
            saveFailed = false
        } catch {
            polishFailed = false
            saveFailed = true
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

    /// S2-5「⋯ → 從錄音重新轉錄」：確認框按了重新轉錄才會叫。
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
