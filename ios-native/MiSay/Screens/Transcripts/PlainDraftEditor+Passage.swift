import SwiftUI

/// 新編輯框的「改這段」（W4）：做法跟 `DraftEditor` 一樣，只有選取範圍的來源不同（這裡是 UTF-16 換成第幾個字）。
/// 送出與切段落在 `PassagePreviewSheet.Request`，兩種編輯框共用。
extension PlainDraftEditor {
    var passageMenu: some View {
        Menu {
            ForEach(PassageRewriteKind.allCases) { kind in
                Button {
                    startPassage(kind)
                } label: {
                    Label(kind.menuTitle, systemImage: kind.systemImage)
                }
            }
        } label: {
            Label("改這段", systemImage: "pencil.line")
                .labelStyle(.titleAndIcon)
        }
        .disabled(selectionOffsets.isEmpty)
    }

    /// 「自己講怎麼改」先問要求，打好按了才送；其他的直接送。
    private func startPassage(_ kind: PassageRewriteKind) {
        let offsets = selectionOffsets
        request = PassagePreviewSheet.Request(
            kind: kind,
            in: text,
            offset: offsets.lowerBound,
            length: offsets.count
        )
        if kind != .custom {
            sendPassage(nil)
        }
    }

    func sendPassage(_ instruction: String?) {
        guard let current = request, !current.isTooLong, !current.isRunning else {
            return
        }
        request?.begin()
        task = Task { @MainActor in
            await runPassage(current, instruction: instruction)
        }
    }

    /// 回來時這頁已經關了或換了另一次請求，就不寫。
    private func runPassage(_ sent: PassagePreviewSheet.Request, instruction: String?) async {
        do {
            let result = try await sent.rewritten(instruction: instruction)
            guard !Task.isCancelled, request?.id == sent.id else {
                return
            }
            request?.finish(result: result)
        } catch {
            guard !Task.isCancelled, request?.id == sent.id else {
                return
            }
            request?.finish(failure: TranscriptDetailView.rewriteFailureMessage(error))
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
            request?.finish(failure: PassagePreviewSheet.Request.movedNote)
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
