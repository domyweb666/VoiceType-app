import Foundation

/// 接著錄整理好之後，接回原本那篇（K3；2026-11-24 Y4 起不離開編輯頁就能錄）。
///
/// 補錄不掉字靠的是這個存檔順序。全部在主執行緒、中間沒有 await，兩邊的寫入不會交錯：
/// 1. 開錄前，編輯頁先把手上的字存好，存不進去就不開錄；游標位置照存好的那份記。
/// 2. 一開始錄就用錄音檔名記下要接到哪一篇（`appendTargets`）。面板不管怎麼關掉、最後由誰按停止，
///    檔名不變，搬進待轉錄之後照樣認得。
/// 3. 轉錄、潤飾照一般錄音走，口語稿與文字稿先存成獨立的一篇。走到這裡 App 被殺，字都在那一篇裡。
/// 4. 接回去（這個檔）：原篇連同接上去的字寫成功，才刪獨立那一篇。寫不成功、原篇不見了，
///    獨立那一篇就留著。原篇正在整理就先等，整理完再接（`finishInFlight`）。
///    刪不掉只會多一篇重複的，不會少字。
/// 5. 原篇正開在編輯頁：流水不碰原篇的檔，交給那頁接（`OpenEditor.takeIn`），那頁先存手上的字，
///    再拿存檔裡最新的那份接、存、換上畫面。同一篇同一時間只有一個人寫，誰也蓋不掉誰。
/// 6. 那頁正在打字就先等（`waitingAppends`）：注音選到一半時換字，編輯框下一個字會拿
///    沒有接上去的那份蓋回來。收鍵盤或離開那頁時接。等的時候 App 被殺，就是獨立一篇。
extension TranscriptionQueue {
    enum TakeInResult: Equatable {
        /// 已經寫進存檔，這是寫進去的那份。
        case taken(Transcript)
        /// 現在不能接（正在打字、正在整理、手上的字存不進去），等一下再叫一次。
        case busy
        /// 接不上：獨立那一篇留著。
        case refused
    }

    /// 正開在詳情頁的一篇。`token` 認是哪一頁：同一篇重開時，新的那頁會比舊的那頁早一步登記。
    struct OpenEditor {
        let token: UUID
        let takeIn: @MainActor (Transcript, InsertionPoint?) -> TakeInResult
    }

    /// 已經存成獨立一篇、等著接回去的那段。
    struct WaitingAppend: Equatable {
        let addedID: UUID
        let target: AppendTarget
    }

    func openEditor(_ editor: OpenEditor, for transcriptID: UUID) {
        openEditors[transcriptID] = editor
    }

    func closeEditor(token: UUID, for transcriptID: UUID) {
        if isEditorOpen(token: token, for: transcriptID) {
            openEditors[transcriptID] = nil
        }
    }

    func isEditorOpen(token: UUID, for transcriptID: UUID) -> Bool {
        openEditors[transcriptID]?.token == token
    }

    /// 還有要接到這篇的錄音（錄音中、待轉錄、整理中、等著接）。
    func hasUnfinishedAppend(to transcriptID: UUID) -> Bool {
        let targets = Array(appendTargets.values) + Array(appendTargetsByTranscript.values)
            + waitingAppends.map(\.target)
        return targets.contains { $0.transcriptID == transcriptID }
    }

    func isWaitingToAppend(_ addedID: UUID) -> Bool {
        waitingAppends.contains { $0.addedID == addedID }
    }

    /// 這篇是接著錄錄的就接回去，回接好的原篇；接不上、還在等的回它自己。
    func mergeIntoAppendTarget(_ added: Transcript) -> Transcript {
        guard let target = appendTargetsByTranscript.removeValue(forKey: added.id) else {
            return added
        }
        waitingAppends.append(WaitingAppend(addedID: added.id, target: target))
        return mergeWaiting(into: target.transcriptID)[added.id] ?? added
    }

    /// 照整理好的順序一段一段接；碰到還不能接就停，後面的不插隊。回接上去的：那段的 id → 接好的原篇。
    @discardableResult
    func mergeWaiting(into transcriptID: UUID) -> [UUID: Transcript] {
        var merged: [UUID: Transcript] = [:]
        for waiting in waitingAppends where waiting.target.transcriptID == transcriptID {
            let result = merge(waiting)
            guard result != .busy else {
                break
            }
            waitingAppends.removeAll { $0 == waiting }
            if case let .taken(target) = result {
                merged[waiting.addedID] = target
            }
        }
        return merged
    }

    /// 獨立那一篇照存檔裡的讀：等的時候可能被改過、被刪掉。正開著給人改的不拿去併。
    private func merge(_ waiting: WaitingAppend) -> TakeInResult {
        let targetID = waiting.target.transcriptID
        let stored = ((try? store.loadAll())?.transcripts ?? []).filter { $0.trashedAt == nil }
        guard openEditors[waiting.addedID] == nil,
              let added = stored.first(where: { $0.id == waiting.addedID })
        else {
            return .refused
        }
        guard !inFlight.contains(targetID.uuidString) else {
            return .busy
        }
        let insertion = waiting.target.insertion
        let result: TakeInResult = if let editor = openEditors[targetID] {
            editor.takeIn(added, insertion)
        } else {
            write(added, into: stored.first { $0.id == targetID }, at: insertion)
        }
        if case .taken = result {
            // 刪不掉只會多一篇重複的，使用者自己刪。
            try? store.delete(id: added.id)
            DiagnosticLog.shared.record("接著錄：接回原本那篇")
        }
        return result
    }

    private func write(
        _ added: Transcript,
        into stored: Transcript?,
        at insertion: InsertionPoint?
    ) -> TakeInResult {
        guard var target = stored else {
            return .refused
        }
        let movedToEnd = Self.append(added, to: &target, at: insertion)
        do {
            try store.save(target)
        } catch {
            return .refused
        }
        if movedToEnd {
            insertionsMovedToEnd.insert(target.id)
        }
        return .taken(target)
    }

    /// 插在記下的游標位置；那附近被改掉找不到，就接在最後面，回 true 讓畫面講一聲。沒記位置就是接在最後面。
    static func append(
        _ added: Transcript,
        to target: inout Transcript,
        at insertion: InsertionPoint?
    ) -> Bool {
        target.adoptRecording(of: added)
        guard let insertion else {
            target.append(added)
            return false
        }
        return !target.insert(added, at: insertion)
    }
}
