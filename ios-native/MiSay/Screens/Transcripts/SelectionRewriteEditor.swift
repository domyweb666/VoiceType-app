import SwiftUI

/// W4（2026-11-09）：文字稿的編輯框，多了選取範圍。選一段之後，鍵盤上方「改這段」選縮短、講清楚一點、
/// 改口語、改書面；改好升起 `PassagePreviewSheet` 給你比，按「換上」才換進文字稿。
/// 選取範圍要 iOS 18 的 `TextEditor(text:selection:)`；iOS 17 照舊只用一般編輯框，沒有這個功能。
@available(iOS 18, *)
struct SelectionRewriteEditor: View {
    @Binding var text: String
    @State private var selection: TextSelection?
    @State private var request: PassagePreviewSheet.Request?
    @State private var task: Task<Void, Never>?

    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    passageMenu
                }
            }
            .sheet(item: $request, onDismiss: cancel) { request in
                PassagePreviewSheet(request: request, onApply: apply) {
                    self.request = nil
                }
            }
    }

    private var passageMenu: some View {
        Menu {
            ForEach(PassageRewriteKind.allCases) { kind in
                Button {
                    start(kind)
                } label: {
                    Label(kind.title, systemImage: kind.systemImage)
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

    private func start(_ kind: PassageRewriteKind) {
        guard let range = selectedRange else {
            return
        }
        let offset = text.distance(from: text.startIndex, to: range.lowerBound)
        let length = text.distance(from: range.lowerBound, to: range.upperBound)
        guard let passage = PassageContext(in: text, offset: offset, length: length),
              !passage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }
        var newRequest = PassagePreviewSheet.Request(
            kind: kind,
            original: passage.text,
            offset: offset
        )
        guard passage.text.count <= PassageRewriteKind.maxPassageCharacters else {
            newRequest.failure = "選的太長了，一次改 3,000 字以內。整篇要改，用「⋯ → 改寫成其他格式」。"
            request = newRequest
            return
        }
        request = newRequest
        task = Task { @MainActor in
            await run(passage, kind: kind, requestID: newRequest.id)
        }
    }

    /// 回來時這頁已經關了或換了另一次請求，就不寫：按了「不要」或拉下去，也不跳訊息（詞彙表語氣規則）。
    private func run(_ passage: PassageContext, kind: PassageRewriteKind, requestID: UUID) async {
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
    private func apply() {
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
        text = replaced
        selection = nil
        request = nil
    }

    private func cancel() {
        task?.cancel()
        task = nil
    }
}
