import SwiftUI

/// 補錄不離開這頁（2026-11-24 Y4）：按麥克風或「⋯ → 接著錄」，錄音面板直接升在這頁上，整理好字回到這裡。
/// 存檔順序寫在 `TranscriptionQueue+Append.swift`。這頁要守的是：開錄前先存；這頁開著時，
/// 只有這頁會寫這篇的存檔（`takeIn`）；接之前先讓編輯框把手上的字交出來，換字之後它才不會拿舊的蓋回來。
extension TranscriptDetailView {
    static let waitingNote = "剛才錄的整理好了，按「完成」就放進來。"
    static let takenInNote = "剛才錄的放進來了。"
    static let movedToEndNote = "剛才錄的那段找不到原本的位置（那附近改過了），接在最後面。"
    static let pendingNote = "整理好會放回這篇，可以先繼續寫。"

    /// 面板、登記成「正開著」、鍵盤收起來時接上等著的那段。包在這裡，主檔的 body 不用再長。
    func withRecording(_ content: some View) -> some View {
        content
            .sheet(isPresented: $showsRecorder, onDismiss: recorderClosed) {
                RecordingSheetView(
                    queue: queue,
                    recorder: recorder,
                    onOpenTranscript: { _ in },
                    onOpenSettings: {},
                    appendingTo: transcript.id,
                    insertingAt: recordInsertion,
                    isInEditor: true
                )
                .presentationDetents([.medium])
                .presentationCornerRadius(Token.Shape.radiusSheet)
            }
            .onChange(of: isEditing) { _, editing in
                if !editing {
                    mergeAfterTyping()
                }
            }
            // 整理「接著錄還沒接回去的那段」時，這頁會換成接好的原篇。
            .onChange(of: transcript.id) { old, _ in
                queue.closeEditor(token: editorToken, for: old)
                registerEditor()
            }
    }

    func registerEditor() {
        let editor = TranscriptionQueue.OpenEditor(token: editorToken) { added, insertion in
            takeIn(added, at: insertion)
        }
        queue.openEditor(editor, for: transcript.id)
    }

    /// 離開這頁：編輯框交出最後的字、存好、登記取消，才把等著的那段直接接進存檔。順序不能換。
    func leaveEditor() {
        endTyping()
        isEditing = false
        isTitleFocused = false
        flushAutosave()
        flushTitle()
        queue.closeEditor(token: editorToken, for: transcript.id)
        queue.mergeWaiting(into: transcript.id)
    }

    /// 系統的編輯框要等它真的收完鍵盤，最後選的字才會交出來；米說自己的在 `takeIn` 裡就收得完。
    private func mergeAfterTyping() {
        guard !usesPlainEditor else {
            queue.mergeWaiting(into: transcript.id)
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.focusDelayMilliseconds))
            queue.mergeWaiting(into: transcript.id)
        }
    }

    var hasUnsavedDraft: Bool {
        transcript.draftText != nil && draftEdit != transcript.draftText
    }

    /// K3「⋯ → 接著錄」：接在這篇最後面。
    func appendRecording() {
        startRecording(at: nil)
    }

    /// 2026-11-09 米：打字時按麥克風，錄好的那段插在游標的位置（中間補內容）。
    func insertRecording(at offset: Int) {
        startRecording(at: offset)
    }

    /// 位置照存好的那份記，所以先存；存不進去就不開（狀態條已經講了）。一次只錄一段。
    private func startRecording(at offset: Int?) {
        guard !recorder.isRecording else {
            showNote("正在錄另一段，先到「錄音」按停止。")
            return
        }
        flushAutosave()
        flushTitle()
        guard !hasUnsavedDraft else {
            return
        }
        recordInsertion = offset.map { InsertionPoint(offset: $0, in: draftEdit) }
        endTyping()
        isEditing = false
        isTitleFocused = false
        showsRecorder = true
    }

    /// 面板收起來，那段還在整理或等網路：講一聲會回到哪裡。
    private func recorderClosed() {
        if queue.hasUnfinishedAppend(to: transcript.id) {
            showNote(Self.pendingNote)
        }
    }

    /// 編輯框馬上交出最後的字（注音選到一半的先定下來），`draftEdit` 才是真的。
    private func endTyping() {
        if usesPlainEditor {
            editorHandle.endTyping()
        } else if isSystemEditorFocused {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }

    /// 流水整理好一段要接回這篇。從讀存檔到換上畫面一口氣做完，中間沒有別人能寫。
    private func takeIn(
        _ added: Transcript,
        at insertion: InsertionPoint?
    ) -> TranscriptionQueue.TakeInResult {
        guard !isEditing, !isPolishing else {
            showNote(Self.waitingNote)
            return .busy
        }
        endTyping()
        flushAutosave()
        guard !hasUnsavedDraft else {
            return .busy
        }
        let before = currentText
        let merged: Transcript
        let movedToEnd: Bool
        do {
            let store = TranscriptStore()
            let stored = try store.loadAll().transcripts.first { $0.id == transcript.id }
            guard var updated = stored, updated.trashedAt == nil else {
                return .refused
            }
            movedToEnd = TranscriptionQueue.append(added, to: &updated, at: insertion)
            try store.save(updated)
            merged = updated
        } catch {
            DiagnosticLog.shared.record("接著錄：接不回正在編輯的那篇 \(type(of: error))")
            return .refused
        }
        transcript = merged
        draftEdit = merged.displayText
        showNote(movedToEnd ? Self.movedToEndNote : Self.takenInNote)
        reveal(EditHistory.changeEnd(from: before, to: merged.displayText))
        return .taken(merged)
    }

    /// 捲到插進來那段的後面。等編輯框換上新的字才捲得到；系統的編輯框要有焦點才放得了游標。
    private func reveal(_ offset: Int) {
        guard usesPlainEditor else {
            jump(to: offset ..< offset)
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.jumpDelayMilliseconds))
            jumpTarget = offset ..< offset
        }
    }
}
