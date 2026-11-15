import SwiftUI

/// 文字稿的另一個編輯框（2026-11-15，寫長文第三批）：設定 → 進階「新的編輯框（試用）」打開才用。
/// 能做的事跟 `DraftEditor` 一樣（格式、在這裡接著錄、改這段、復原重做、大綱跳轉），底下換成 `PlainTextView`。
/// 多的一樣：放了游標一定把那裡捲進畫面。鍵盤上方那排不是系統的鍵盤工具列（那個只認系統的輸入框），
/// 是貼在鍵盤上面的一條，長相與順序照 `DraftEditor`。
struct PlainDraftEditor: View {
    @Binding var text: String
    let canRecordHere: Bool
    /// 給游標在第幾個字（Character）；有選一段字就給那段的後面。
    let onRecordHere: (Int) -> Void
    @Binding var isEditing: Bool
    /// 大綱與尋找要跳到第幾個字；放好游標就清掉。
    @Binding var jump: Range<Int>?
    /// 下面這幾個 `PlainDraftEditor+Passage.swift` 要用，所以不加 private。
    @State var history = EditHistory()
    @State var selection = NSRange(location: 0, length: 0)
    @State var scrollToken = 0
    @State var request: PassagePreviewSheet.Request?
    @State var task: Task<Void, Never>?

    var body: some View {
        PlainTextView(
            text: $text,
            selection: $selection,
            isEditing: $isEditing,
            scrollToken: scrollToken
        )
        .safeAreaInset(edge: .bottom) {
            if isEditing {
                bar
            }
        }
        .onChange(of: text) { old, new in history.record(from: old, to: new) }
        .onChange(of: jump) { _, target in jumpIfNeeded(target) }
        .toolbar {
            if isEditing {
                ToolbarItemGroup(placement: .topBarTrailing) { historyButtons }
            }
        }
        .sheet(item: $request, onDismiss: cancelPassage) { request in
            PassagePreviewSheet(request: request, onApply: applyPassage) {
                self.request = nil
            }
        }
    }

    /// 游標或選取在第幾個字。
    var selectionOffsets: Range<Int> {
        TextOffsets.characters(of: selection, in: text)
    }

    /// 照第幾個字放游標或選起來，並把那裡捲進畫面。
    func select(_ offsets: Range<Int>) {
        selection = TextOffsets.utf16Range(of: offsets, in: text)
        scrollToken += 1
    }

    private var bar: some View {
        HStack(spacing: Token.Space.xl) {
            formatButton("標題", systemImage: "number") {
                MarkdownFormatting.toggleLinePrefix(
                    MarkdownFormatting.headingPrefix,
                    in: $0,
                    selection: $1
                )
            }
            formatButton(
                "粗體",
                systemImage: "bold",
                change: MarkdownFormatting.toggleBold(in:selection:)
            )
            formatButton("清單", systemImage: "list.bullet") {
                MarkdownFormatting.toggleLinePrefix(
                    MarkdownFormatting.listPrefix,
                    in: $0,
                    selection: $1
                )
            }
            Button {
                onRecordHere(selectionOffsets.upperBound)
            } label: {
                Image(systemName: "mic.badge.plus")
            }
            .accessibilityLabel("在這裡接著錄")
            .disabled(!canRecordHere)
            Spacer()
            passageMenu
        }
        .font(Token.Fonts.rowTitle)
        .tint(Token.Colors.link)
        .padding(.horizontal, Token.Space.l)
        .frame(height: Token.Shape.minTap)
        .background(Token.Colors.groupedBackground)
    }

    private func formatButton(
        _ label: String,
        systemImage: String,
        change: @escaping (String, Range<Int>) -> MarkdownFormatting.Edit
    ) -> some View {
        Button {
            let edit = change(text, selectionOffsets)
            text = edit.text
            select(edit.selection)
        } label: {
            Image(systemName: systemImage)
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var historyButtons: some View {
        Button {
            restore(history.undo(current: text))
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .accessibilityLabel("復原")
        .disabled(!history.canUndo)
        Button {
            restore(history.redo(current: text))
        } label: {
            Image(systemName: "arrow.uturn.forward")
        }
        .accessibilityLabel("重做")
        .disabled(!history.canRedo)
    }

    /// 整份字換回去，游標放在變動的那一段後面。
    private func restore(_ restored: String?) {
        guard let restored else {
            return
        }
        let caret = EditHistory.changeEnd(from: text, to: restored)
        text = restored
        select(caret ..< caret)
    }

    private func jumpIfNeeded(_ target: Range<Int>?) {
        guard let target else {
            return
        }
        select(target)
        jump = nil
    }
}
