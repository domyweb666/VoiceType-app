import SwiftUI

/// 編輯框的復原、重做，與「大綱與尋找」跳到某個位置（2026-11-15 米：要在手機上寫五千字以上）。
/// 拆檔：`DraftEditor` 主型別快到 200 行。
@available(iOS 18, *)
extension DraftEditor {
    /// 打字時頂上右邊多兩顆（備忘錄也放這裡），在「大綱與尋找」「完成」的左邊。
    @ViewBuilder
    var historyButtons: some View {
        Button(action: undo) {
            Image(systemName: "arrow.uturn.backward")
        }
        .accessibilityLabel("復原")
        .disabled(!history.canUndo)
        Button(action: redo) {
            Image(systemName: "arrow.uturn.forward")
        }
        .accessibilityLabel("重做")
        .disabled(!history.canRedo)
    }

    func undo() {
        let current = text
        guard let restored = history.undo(current: current) else {
            return
        }
        restore(restored, from: current)
    }

    func redo() {
        let current = text
        guard let restored = history.redo(current: current) else {
            return
        }
        restore(restored, from: current)
    }

    /// 整份字換回去，游標放在變動的那一段後面，人看得到剛才回復了哪裡。
    private func restore(_ restored: String, from current: String) {
        let caret = EditHistory.changeEnd(from: current, to: restored)
        text = restored
        select(caret ..< caret)
    }

    func jumpIfNeeded(_ target: Range<Int>?) {
        guard let target else {
            return
        }
        select(target)
        jump = nil
    }

    /// 照第幾個字放游標或選起來；超出就停在最後，不越界。
    func select(_ offsets: Range<Int>) {
        let end = text.endIndex
        let lower = text.index(text.startIndex, offsetBy: offsets.lowerBound, limitedBy: end) ?? end
        let upper = text.index(lower, offsetBy: offsets.count, limitedBy: end) ?? end
        selection = lower == upper
            ? TextSelection(insertionPoint: lower)
            : TextSelection(range: lower ..< upper)
    }
}
