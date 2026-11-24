import Foundation

/// 粗體（W5）。從主檔搬出來，讓它留在 300 行內，所以共用的那幾個不加 private。
extension MarkdownFormatting {
    /// 粗體：選到的字前後加 `**`；都已經是粗體就拿掉。沒選字時插一對，游標停在中間。
    /// 選好幾行就一行一行包，行首記號、空白行不包：`**` 跨行或包住「- 」就不是粗體了。
    static func toggleBold(in text: String, selection: Range<Int>) -> Edit {
        var characters = Array(text)
        let selection = clamped(selection, count: characters.count)
        let pieces = selection.isEmpty
            ? [selection]
            : boldPieces(in: characters, covering: selection)
        guard let first = pieces.first, let last = pieces.last else {
            return Edit(text: text, selection: selection)
        }
        let isRemoving = pieces.allSatisfy { isBold($0, in: characters) }
        let changed = isRemoving ? pieces : pieces.filter { !isBold($0, in: characters) }
        let changes = changed.flatMap { piece in
            boldChanges(for: piece, isRemoving: isRemoving)
        }
        for change in changes.reversed() {
            let old = change.start ..< change.start + change.removed
            characters.replaceSubrange(old, with: change.inserted)
        }
        let lower = moved(first.lowerBound, by: Array(changes.prefix(1)))
        // 最後那個 `**` 加在選取後面，選取不包它。
        let upper = selection.isEmpty
            ? lower
            : moved(last.upperBound, by: changes.filter { $0.start < last.upperBound })
        return Edit(text: String(characters), selection: lower ..< upper)
    }

    private static func boldChanges(for piece: Range<Int>, isRemoving: Bool) -> [Change] {
        let marker = Array(boldMarker)
        guard isRemoving else {
            return [piece.lowerBound, piece.upperBound].map {
                Change(start: $0, removed: 0, inserted: marker)
            }
        }
        return [piece.lowerBound - marker.count, piece.upperBound].map {
            Change(start: $0, removed: marker.count, inserted: [])
        }
    }

    /// 選取碰到的每一行各一段：跳過行首記號、空白行；選到的字自己帶著 `**` 就取裡面。
    private static func boldPieces(
        in characters: [Character],
        covering selection: Range<Int>
    ) -> [Range<Int>] {
        lineStarts(in: characters, covering: selection).compactMap { start in
            let mark = marker(in: characters, at: start)
            let length = characters[start...].prefix { !$0.isNewline }.count
            let lower = max(selection.lowerBound, start + mark.indent + mark.length)
            let upper = min(selection.upperBound, start + length)
            guard lower < upper, !characters[lower ..< upper].allSatisfy(\.isWhitespace) else {
                return nil
            }
            return withoutBoldMarks(lower ..< upper, in: characters)
        }
    }

    private static func withoutBoldMarks(
        _ piece: Range<Int>,
        in characters: [Character]
    ) -> Range<Int> {
        let marker = Array(boldMarker)
        var lower = piece.lowerBound
        var upper = piece.upperBound
        if hasMarker(marker, in: characters, at: lower) {
            lower += marker.count
        }
        if hasMarker(marker, in: characters, at: upper - marker.count) {
            upper -= marker.count
        }
        guard lower < upper, isBold(lower ..< upper, in: characters),
              !String(characters[lower ..< upper]).contains(boldMarker)
        else {
            return piece
        }
        return lower ..< upper
    }

    private static func isBold(_ piece: Range<Int>, in characters: [Character]) -> Bool {
        let marker = Array(boldMarker)
        return hasMarker(marker, in: characters, at: piece.lowerBound - marker.count)
            && hasMarker(marker, in: characters, at: piece.upperBound)
    }
}
