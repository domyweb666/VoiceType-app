import SwiftUI

/// 用系統 TextEditor 的編輯框（iOS 18 起）。2026-11-24 起是退路，設定 → 進階「用舊的編輯框」打開才用。鍵盤上方一排：
/// - 格式：共用的 `FormatBar`，只插 Markdown 記號，文字稿還是純文字。
/// - 2026-11-09 在這裡接著錄：記下游標位置，錄好、整理好就插回這裡（米：中間要補內容，不是只能接在最後）。
/// - W4「改這段」：選一段叫 AI 縮短、講清楚一點、改口語、改書面；改好升起 `PassagePreviewSheet`，按「換上」才換。
///   在 `DraftEditor+Passage.swift`。
/// 選取範圍要 iOS 18 的 `TextEditor(text:selection:)`；iOS 17 照舊只用一般編輯框，沒有這一排。
/// 2026-11-10：v0.2.7 換成 UIKit 編輯框（邊打邊變樣）後，米真機打開文字稿一片白，退回系統的 TextEditor；
/// 那版在 commit 6e0a31a（`MarkdownTextView`、`MarkdownStyler`），找到原因再接回來。
@available(iOS 18, *)
struct DraftEditor: View {
    @Binding var text: String
    /// 整理中不給在這裡接著錄：整理完存回來會蓋掉插進去的字（跟「⋯ → 接著錄」同一條）。
    let canRecordHere: Bool
    /// 給游標在第幾個字（Character）；有選一段字就給那段的後面。
    let onRecordHere: (Int) -> Void
    /// 鍵盤是不是升著：頂上的復原、重做只在打字時出現。
    let isEditing: Bool
    /// 大綱與尋找要跳到第幾個字；放好游標就清掉。
    @Binding var jump: Range<Int>?
    /// 復原、重做（`DraftEditor+History.swift` 要用，所以這兩個不加 private）。
    @State var history = EditHistory()
    @State var selection: TextSelection?
    /// `DraftEditor+Passage.swift` 要用，所以這兩個不加 private。
    @State var request: PassagePreviewSheet.Request?
    @State var task: Task<Void, Never>?
    @State private var linkRequest: LinkSheet.Request?

    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .accessibilityLabel("文字稿正文")
            // 只縮字，底下的格式列要滿版（跟 `PlainDraftEditor` 一樣）。
            .padding(.horizontal, Token.Space.editorSide)
            .safeAreaInset(edge: .bottom) {
                if isEditing {
                    FormatBar(
                        canRecordHere: canRecordHere,
                        onFormat: format,
                        onLink: startLink,
                        onRecordHere: { onRecordHere(selectionOffsets.upperBound) },
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
            .sheet(item: $request, onDismiss: cancel) { request in
                PassagePreviewSheet(request: request, onSend: send, onApply: apply) {
                    self.request = nil
                }
            }
            .sheet(item: $linkRequest) { request in
                LinkSheet { url in addLink(url, for: request) }
            }
    }

    private func startLink() {
        linkRequest = LinkSheet.Request(selection: selectionOffsets, text: text)
    }

    private func addLink(_ url: String, for request: LinkSheet.Request) {
        guard let edit = request.adding(url, to: text) else {
            return
        }
        text = edit.text
        select(edit.selection)
    }

    /// 游標或選取在第幾個字；還沒點進來沒有游標，就當在最後面。
    private var selectionOffsets: Range<Int> {
        guard let selection, case let .selection(range) = selection.indices,
              range.upperBound <= text.endIndex
        else {
            return text.count ..< text.count
        }
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        return lower ..< lower + text.distance(from: range.lowerBound, to: range.upperBound)
    }

    /// 改完的字是新字串，游標照第幾個字放回去；超出就停在最後，不越界。
    private func format(_ change: (String, Range<Int>) -> MarkdownFormatting.Edit) {
        let edit = change(text, selectionOffsets)
        text = edit.text
        select(edit.selection)
    }
}
