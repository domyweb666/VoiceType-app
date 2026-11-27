import SwiftUI

/// 文字稿的編輯框（2026-11-15 試用，2026-11-24 轉正、預設用這個）。
/// 能做的事跟 `DraftEditor` 一樣（格式、在這裡接著錄、改這段、復原重做、大綱跳轉），底下換成 `PlainTextView`。
/// 多的一樣：放了游標一定把那裡捲進畫面。
struct PlainDraftEditor: View {
    @Binding var text: String
    let canRecordHere: Bool
    /// 給游標在第幾個字（Character）；有選一段字就給那段的後面。
    let onRecordHere: (Int) -> Void
    @Binding var isEditing: Bool
    /// 大綱與尋找要跳到第幾個字；放好游標就清掉。
    @Binding var jump: Range<Int>?
    /// 底下那個 UITextView：整份字要換掉之前，先請它把注音選到一半的字定下來。
    let handle: PlainTextHandle
    /// 下面這幾個 `PlainDraftEditor+Passage.swift` 要用，所以不加 private。
    @State var history = EditHistory()
    @State var selection = NSRange(location: 0, length: 0)
    @State var scrollToken = 0
    @State var request: PassagePreviewSheet.Request?
    @State var task: Task<Void, Never>?
    @State private var linkRequest: LinkSheet.Request?

    var body: some View {
        PlainTextView(
            text: $text,
            selection: $selection,
            isEditing: $isEditing,
            scrollToken: scrollToken,
            handle: handle
        )
        // 編輯框自己裡面還有一點內距，外面補到跟清單卡片的字差不多齊。只縮字，底下的格式列要滿版。
        .padding(.horizontal, Token.Space.editorSide)
        .safeAreaInset(edge: .bottom) {
            if isEditing {
                FormatBar(
                    canRecordHere: canRecordHere,
                    onFormat: format,
                    onLink: startLink,
                    onRecordHere: recordHere,
                    passageMenu: { passageMenu }
                )
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
            PassagePreviewSheet(
                request: request,
                onSend: sendPassage,
                onApply: applyPassage
            ) {
                self.request = nil
            }
        }
        .sheet(item: $linkRequest) { request in
            LinkSheet { url in addLink(url, for: request) }
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

    /// 先把注音選到一半的字定下來，位置才算得準。
    private func recordHere() {
        handle.commitComposing()
        onRecordHere(selectionOffsets.upperBound)
    }

    private func format(_ change: (String, Range<Int>) -> MarkdownFormatting.Edit) {
        handle.commitComposing()
        let edit = change(text, selectionOffsets)
        text = edit.text
        select(edit.selection)
    }

    private func startLink() {
        handle.commitComposing()
        linkRequest = LinkSheet.Request(selection: selectionOffsets, text: text)
    }

    private func addLink(_ url: String, for request: LinkSheet.Request) {
        guard let edit = request.adding(url, to: text) else {
            return
        }
        text = edit.text
        select(edit.selection)
    }

    @ViewBuilder
    private var historyButtons: some View {
        Button {
            handle.commitComposing()
            restore(history.undo(current: text))
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .accessibilityLabel("復原")
        .disabled(!history.canUndo)
        Button {
            handle.commitComposing()
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
