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
    func polishThis() {
        guard transcript.draftText == nil else {
            return
        }
        polishFailed = false
        isPolishing = true
        let settings = AppSettings.shared
        // 開始時就記下模型與潤飾方式：整理中途改了設定，記在這篇上的仍是實際送出去的那個。
        let model = settings.polishModel
        let style = settings.polishStyle
        let source = transcript
        polishTask = Task { @MainActor in
            do {
                let draft = try await Polisher().polish(
                    rawText: source.rawText,
                    model: model,
                    style: style,
                    vocabulary: settings.vocabulary
                )
                // 回應回來、還沒套用的那一瞬間按了取消，也不准存。
                try Task.checkCancellation()
                var updated = transcript
                updated.applyPolish(draft, model: model, style: style)
                try TranscriptStore().save(updated)
                transcript = updated
                draftEdit = draft
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

    func cancelPolish() {
        polishTask?.cancel()
        polishTask = nil
        isPolishing = false
    }
}
