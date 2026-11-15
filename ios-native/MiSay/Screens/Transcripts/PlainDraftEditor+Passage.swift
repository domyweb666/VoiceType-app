import SwiftUI

/// 新編輯框的「改這段」（W4）：做法跟 `DraftEditor` 一樣，只有選取範圍的來源不同（這裡是 UTF-16 換成第幾個字）。
/// 兩邊各一份：這個編輯框還在試用，先不去動 `DraftEditor` 那份已經在用的。
extension PlainDraftEditor {
    var passageMenu: some View {
        Menu {
            ForEach(PassageRewriteKind.allCases) { kind in
                Button {
                    startPassage(kind)
                } label: {
                    Label(kind.title, systemImage: kind.systemImage)
                }
            }
        } label: {
            Label("改這段", systemImage: "pencil.line")
                .labelStyle(.titleAndIcon)
        }
        .disabled(selectionOffsets.isEmpty)
    }

    private func startPassage(_ kind: PassageRewriteKind) {
        let offsets = selectionOffsets
        let start = offsets.lowerBound
        guard !offsets.isEmpty,
              let passage = PassageContext(in: text, offset: start, length: offsets.count),
              !passage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }
        var newRequest = PassagePreviewSheet.Request(
            kind: kind,
            original: passage.text,
            offset: start
        )
        guard passage.text.count <= PassageRewriteKind.maxPassageCharacters else {
            newRequest.failure = "選的太長了，一次改 3,000 字以內。整篇要改，用「⋯ → 改寫成其他格式」。"
            request = newRequest
            return
        }
        request = newRequest
        task = Task { @MainActor in
            await runPassage(passage, kind: kind, requestID: newRequest.id)
        }
    }

    /// 回來時這頁已經關了或換了另一次請求，就不寫。
    private func runPassage(
        _ passage: PassageContext,
        kind: PassageRewriteKind,
        requestID: UUID
    ) async {
        do {
            let result = try await Polisher().rewritePassage(
                passage,
                kind: kind,
                model: AppSettings.shared.polishModel,
                vocabulary: AppSettings.shared.vocabulary
            )
            guard !Task.isCancelled, request?.id == requestID else {
                return
            }
            request?.result = result
        } catch {
            guard !Task.isCancelled, request?.id == requestID else {
                return
            }
            request?.failure = TranscriptDetailView.rewriteFailureMessage(error)
        }
    }

    /// 等的時候字可能被改過：照第幾個字找回原本那段，對不上就找它在哪，找不到不換，說一聲。
    func applyPassage() {
        guard let current = request, let result = current.result else {
            return
        }
        guard let replaced = PassageContext.replacing(
            current.original,
            at: current.offset,
            with: result,
            in: text
        ) else {
            request?.result = nil
            request?.failure = "這段在等的時候被改過了，找不到原本那段，沒有換上。"
            return
        }
        let caret = EditHistory.changeEnd(from: text, to: replaced)
        text = replaced
        select(caret ..< caret)
        request = nil
    }

    func cancelPassage() {
        task?.cancel()
        task = nil
    }
}
