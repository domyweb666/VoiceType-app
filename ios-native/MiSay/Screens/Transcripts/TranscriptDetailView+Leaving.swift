import SwiftUI

/// 回到這頁、離開這頁要收的：換成存檔裡最新的；空白新文稿不留，收掉之後人又回來就放回去。
/// 改寫稿與原篇會一頁疊一頁（`+Derived`），被蓋住的那頁等於離開過，回來一樣走這裡。
extension TranscriptDetailView {
    /// K3：接著錄、從錄音重新轉錄都可能在這頁不在畫面上時改了這篇；回來先讀最新的。
    func pageAppeared() {
        // 疊在上面那頁的「改寫好的」裡把這篇刪了：不留在一篇要進垃圾桶的文稿上繼續寫。
        guard !derived.isDeleted(transcript.id) else {
            closeDeletedPage()
            return
        }
        undoDiscard()
        reloadFromStore()
        registerEditor()
        focusIfBlank()
        if queue.insertionsMovedToEnd.remove(transcript.id) != nil {
            showNote(Self.movedToEndNote)
        }
    }

    /// 退回來的動畫跑完才退得了下一頁。
    private func closeDeletedPage() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.focusDelayMilliseconds))
            dismiss()
        }
    }

    /// 這頁不在畫面上時，存檔可能被換過（接著錄、重轉、別處整理完）：回來一律換成存檔裡的，再登記成正開著。
    /// 不比 `updatedAt`：存檔只記到秒，同一秒裡接上去的會看不出來。
    /// 手上有還沒存進去的字（上次存檔失敗）就留著手上的，存檔裡那份下次存之前先留成一版。
    /// 讀不到存檔就什麼都不換，改寫好的那幾篇也照舊列著。
    func reloadFromStore() {
        guard let transcripts = try? TranscriptStore().loadAll().transcripts else {
            return
        }
        derived.refresh(sourceID: transcript.id, from: transcripts)
        guard !isPolishing, let stored = transcripts.first(where: { $0.id == transcript.id }) else {
            return
        }
        let keepsHand = hasUnsavedDraft
        transcript = stored
        if keepsHand {
            versionDueAt = nil
        } else {
            draftEdit = stored.draftText ?? ""
        }
    }

    /// 新文稿一個字都沒寫就離開：直接刪，不留一篇空白的在清單。寫過又全刪的進垃圾桶（Y6）。
    /// 取過標題、還有錄音要接回來、有改寫稿、手上還有沒存進去的，都留著。
    func discardIfBlank() {
        guard openedBlank, derived.transcripts.isEmpty, !hasUnsavedDraft,
              Self.cleanedTitle(titleEdit) == nil, transcript.hasNothingLeft,
              !queue.hasUnfinishedAppend(to: transcript.id)
        else {
            return
        }
        do {
            // 手上是空的不代表存檔是空的：離開這頁時，等著的那段錄音可能剛接進存檔。
            let store = TranscriptStore()
            guard let stored = try store.load(id: transcript.id), stored.hasNothingLeft else {
                return
            }
            if stored.isBlankDraft {
                try store.delete(id: stored.id)
            } else {
                try store.moveToTrash(id: stored.id)
            }
            wasDiscarded = true
        } catch {
            DiagnosticLog.shared.record("空白新文稿沒刪掉：\(type(of: error))")
        }
    }

    /// 切到別的分頁也算離開，這頁其實還開著：回來（或字晚一步才到）先放回去，不然接下來打的字沒地方存。
    func undoDiscard() {
        guard wasDiscarded else {
            return
        }
        do {
            let store = TranscriptStore()
            if try store.load(id: transcript.id) == nil {
                if try store.trashedIDs().contains(transcript.id) {
                    try store.restoreFromTrash(id: transcript.id)
                } else if transcript.isBlankDraft {
                    try store.save(transcript, openedInGeneration: openedEraseGeneration)
                }
            }
            wasDiscarded = false
        } catch {
            DiagnosticLog.shared.record("收掉的新文稿沒放回來：\(type(of: error))")
        }
    }
}
