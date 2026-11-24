import SwiftUI

/// 編輯框的「改這段」（W4；2026-11-24 加「自己講怎麼改」）。拆檔：`DraftEditor` 主型別快到 200 行。
/// 送出與切段落在 `PassagePreviewSheet.Request`，兩種編輯框共用。
@available(iOS 18, *)
extension DraftEditor {
    var passageMenu: some View {
        Menu {
            ForEach(PassageRewriteKind.allCases) { kind in
                Button {
                    start(kind)
                } label: {
                    Label(kind.menuTitle, systemImage: kind.systemImage)
                }
            }
        } label: {
            Label("改這段", systemImage: "pencil.line")
                .labelStyle(.titleAndIcon)
        }
        .tint(Token.Colors.link)
        .disabled(selectedRange == nil)
    }

    /// 只認一段連續的選取；沒選、只放了游標、選了好幾段都不算。
    private var selectedRange: Range<String.Index>? {
        guard let selection, case let .selection(range) = selection.indices, !range.isEmpty,
              range.upperBound <= text.endIndex
        else {
            return nil
        }
        return range
    }

    /// 「自己講怎麼改」先問要求，打好按了才送；其他的直接送。
    private func start(_ kind: PassageRewriteKind) {
        guard let range = selectedRange else {
            return
        }
        let offset = text.distance(from: text.startIndex, to: range.lowerBound)
        let length = text.distance(from: range.lowerBound, to: range.upperBound)
        request = PassagePreviewSheet.Request(
            kind: kind,
            in: text,
            offset: offset,
            length: length
        )
        if kind != .custom {
            send(nil)
        }
    }

    func send(_ instruction: String?) {
        guard let current = request, !current.isTooLong, !current.isRunning else {
            return
        }
        request?.begin()
        task = Task { @MainActor in
            await run(current, instruction: instruction)
        }
    }

    /// 回來時這頁已經關了或換了另一次請求，就不寫：按了「不要」或拉下去，也不跳訊息（詞彙表語氣規則）。
    private func run(_ sent: PassagePreviewSheet.Request, instruction: String?) async {
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
    func apply() {
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
        text = replaced
        selection = nil
        request = nil
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
