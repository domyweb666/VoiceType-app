import SwiftUI

/// 文字稿的編輯框（`MarkdownTextView`），打字時底下浮一排：
/// - W5 標題、粗體、清單：插 Markdown 記號（`MarkdownFormatting`），編輯框直接畫成標題、粗體、圓點的樣子。
/// - 2026-11-09 在這裡接著錄：記下游標位置，錄好、整理好就插回這裡（米：中間要補內容，不是只能接在最後）。
/// - W4「改這段」：選一段叫 AI 縮短、講清楚一點、改口語、改書面；改好升起 `PassagePreviewSheet`，按「換上」才換。
/// 以前用 SwiftUI 的 TextEditor，要 iOS 18 才拿得到選取範圍；換成 UITextView 之後 iOS 17 也有這一排。
/// 這一排放在畫面底下（鍵盤會把它頂上去），不掛在鍵盤上：SwiftUI 的鍵盤工具列只認 SwiftUI 自己的輸入框。
struct DraftEditor: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    /// 整理中不給在這裡接著錄：整理完存回來會蓋掉插進去的字（跟「⋯ → 接著錄」同一條）。
    let canRecordHere: Bool
    /// 給游標在第幾個字（Character）；有選一段字就給那段的後面。
    let onRecordHere: (Int) -> Void
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var request: PassagePreviewSheet.Request?
    @State private var task: Task<Void, Never>?

    var body: some View {
        MarkdownTextView(text: $text, selection: $selection, isEditing: $isEditing)
            .safeAreaInset(edge: .bottom) {
                if isEditing {
                    editingBar
                }
            }
            .sheet(item: $request, onDismiss: cancel) { request in
                PassagePreviewSheet(request: request, onApply: apply) {
                    self.request = nil
                }
            }
    }

    private var editingBar: some View {
        HStack(spacing: Token.Space.xs) {
            formatButtons
            recordHereButton
            Spacer()
            passageMenu
        }
        .font(Token.Fonts.rowTitle)
        .foregroundStyle(Token.Colors.textPrimary)
        .padding(.horizontal, Token.Space.s)
        .background(.bar)
    }

    /// W5：三顆都是切換，再按一次拿掉。圖示配無障礙標籤，不只靠圖。
    @ViewBuilder
    private var formatButtons: some View {
        barButton("標題", systemImage: "number") {
            format { MarkdownFormatting.toggleLinePrefix(
                MarkdownFormatting.headingPrefix,
                in: $0,
                selection: $1
            ) }
        }
        barButton("粗體", systemImage: "bold") {
            format(MarkdownFormatting.toggleBold(in:selection:))
        }
        barButton("清單", systemImage: "list.bullet") {
            format { MarkdownFormatting.toggleLinePrefix(
                MarkdownFormatting.listPrefix,
                in: $0,
                selection: $1
            ) }
        }
    }

    private var recordHereButton: some View {
        barButton("在這裡接著錄", systemImage: "mic.badge.plus") {
            onRecordHere(selectionOffsets.upperBound)
        }
        .disabled(!canRecordHere)
        .opacity(canRecordHere ? 1 : Token.Motion.disabledOpacity)
    }

    private func barButton(
        _ label: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(minWidth: Token.Shape.minTap, minHeight: Token.Shape.minTap)
        }
        .accessibilityLabel(label)
    }

    /// 游標或選取在第幾個字（編輯框給的是 UTF-16 位置，格式與改一段都用第幾個字）。
    private var selectionOffsets: Range<Int> {
        guard let range = Range(selection, in: text) else {
            return text.count ..< text.count
        }
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        return lower ..< lower + text.distance(from: range.lowerBound, to: range.upperBound)
    }

    /// 第幾個字換回編輯框要的 UTF-16 位置；超出就停在最後，不越界。
    private func select(_ offsets: Range<Int>) {
        let end = text.endIndex
        let lower = text.index(text.startIndex, offsetBy: offsets.lowerBound, limitedBy: end) ?? end
        let upper = text.index(lower, offsetBy: offsets.count, limitedBy: end) ?? end
        selection = NSRange(lower ..< upper, in: text)
    }

    /// 改完的字是新字串，游標照第幾個字放回去。
    private func format(_ change: (String, Range<Int>) -> MarkdownFormatting.Edit) {
        let edit = change(text, selectionOffsets)
        text = edit.text
        select(edit.selection)
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
                .frame(minHeight: Token.Shape.minTap)
        }
        .foregroundStyle(
            selectionOffsets.isEmpty ? Token.Colors.textSecondary : Token.Colors.link
        )
        .disabled(selectionOffsets.isEmpty)
    }

    private func start(_ kind: PassageRewriteKind) {
        let offsets = selectionOffsets
        let lower = offsets.lowerBound
        guard !offsets.isEmpty,
              let passage = PassageContext(in: text, offset: lower, length: offsets.count),
              !passage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }
        var newRequest = PassagePreviewSheet.Request(
            kind: kind,
            original: passage.text,
            offset: offsets.lowerBound
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
        select(current.offset ..< current.offset)
        request = nil
    }

    private func cancel() {
        task?.cancel()
        task = nil
    }
}
