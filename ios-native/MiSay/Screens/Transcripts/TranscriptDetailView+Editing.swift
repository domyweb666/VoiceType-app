import SwiftUI

/// E2 改字自動存、E4 重新潤飾、複製。2026-11-07 從詳情檔搬出來，讓它留在 300 行內。
extension TranscriptDetailView {
    func copy() {
        UIPasteboard.general.string = currentText
        copyCount += 1
        showsCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            showsCopied = false
        }
    }

    func scheduleAutosave() {
        guard transcript.draftText != nil, draftEdit != transcript.draftText else {
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

    /// 存不進去只能大聲：用潤飾失敗那一行的位置顯示。畫面上的字不會丟（還在編輯框裡）。
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

    func repolish(_ mode: RepolishMode) {
        flushAutosave()
        lastRepolishMode = mode
        polishFailed = false
        isPolishing = true
        let settings = AppSettings.shared
        // 開始時就記下模型：潤飾中途改了設定，記在這篇上的仍是實際送出去的那個。
        let model = settings.polishModel
        let source = transcript
        polishTask = Task { @MainActor in
            do {
                let draft = try await Polisher().polish(
                    rawText: source.rawText,
                    model: model,
                    systemPrompt: settings.effectivePolishPrompt,
                    vocabulary: settings.vocabulary
                )
                // 回應回來、還沒套用的那一瞬間按了取消，也不准蓋掉。
                try Task.checkCancellation()
                try applyRepolish(draft, mode: mode, model: model)
            } catch is CancellationError {
                // 使用者自己按取消，不跳訊息（詞彙表語氣規則）。
            } catch OpenAIClient.Failure.transport(.cancelled) {
                // 同上：取消在連線層的樣子。
            } catch {
                polishFailed = true
            }
            isPolishing = false
        }
    }

    func applyRepolish(_ draft: String, mode: RepolishMode, model: String) throws {
        let store = TranscriptStore()
        switch mode {
        case .overwrite:
            var updated = transcript
            updated.draftText = draft
            updated.polishModel = model
            updated.updatedAt = Date()
            try store.save(updated)
            transcript = updated
            draftEdit = draft
        case .saveAsNew:
            let copy = Transcript(
                durationSeconds: transcript.durationSeconds,
                rawText: transcript.rawText,
                draftText: draft,
                polishModel: model
            )
            try store.save(copy)
            dismiss()
        }
    }

    func cancelPolish() {
        polishTask?.cancel()
        polishTask = nil
        isPolishing = false
    }
}
