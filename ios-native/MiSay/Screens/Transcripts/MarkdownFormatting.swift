import Foundation

/// W5 文字稿的簡單格式（2026-11-09）：鍵盤上方三顆，標題、粗體、清單。文字稿還是純文字，
/// 只是插入 Markdown 記號，存成 Markdown 時照原樣出去，Obsidian 直接看得懂。不做富文字編輯器。
/// 位置一律用第幾個字（Character），改完的字是新的字串，舊的 String.Index 不能再用。
enum MarkdownFormatting {
    struct Edit: Equatable {
        let text: String
        /// 改完之後游標或選取範圍在哪（第幾個字）。
        let selection: Range<Int>
    }

    static let headingPrefix = "## "
    static let listPrefix = "- "
    static let boldMarker = "**"

    /// 標題、清單：選到的每一行（沒選就是游標那一行）開頭加記號；全部都已經有了就拿掉。
    static func toggleLinePrefix(_ prefix: String, in text: String, selection: Range<Int>) -> Edit {
        var characters = Array(text)
        let marker = Array(prefix)
        let selection = clamped(selection, count: characters.count)
        let starts = lineStarts(in: characters, covering: selection)
        let isRemoving = starts.allSatisfy { hasMarker(marker, in: characters, at: $0) }
        // 照原本的位置記每一行加了或少了幾個字，算游標新的位置用。
        let changes: [(start: Int, delta: Int)] = starts.compactMap { start in
            if isRemoving {
                return (start, -marker.count)
            }
            return hasMarker(marker, in: characters, at: start) ? nil : (start, marker.count)
        }
        // 從後面改回來，前面的位置才不會跑掉。
        for change in changes.reversed() {
            if change.delta < 0 {
                characters.removeSubrange(change.start ..< change.start - change.delta)
            } else {
                characters.insert(contentsOf: marker, at: change.start)
            }
        }
        let mapped = moved(selection.lowerBound, by: changes) ..< moved(
            selection.upperBound,
            by: changes
        )
        return Edit(text: String(characters), selection: mapped)
    }

    /// 粗體：選到的字前後加 `**`；前後已經是 `**` 就拿掉。沒選字時插一對，游標停在中間。
    static func toggleBold(in text: String, selection: Range<Int>) -> Edit {
        var characters = Array(text)
        let marker = Array(boldMarker)
        let selection = clamped(selection, count: characters.count)
        let lower = selection.lowerBound
        let upper = selection.upperBound
        let isWrapped = lower >= marker.count
            && hasMarker(marker, in: characters, at: lower - marker.count)
            && hasMarker(marker, in: characters, at: upper)
        if isWrapped {
            characters.removeSubrange(upper ..< upper + marker.count)
            characters.removeSubrange(lower - marker.count ..< lower)
            return Edit(
                text: String(characters),
                selection: lower - marker.count ..< upper - marker.count
            )
        }
        characters.insert(contentsOf: marker, at: upper)
        characters.insert(contentsOf: marker, at: lower)
        return Edit(
            text: String(characters),
            selection: lower + marker.count ..< upper + marker.count
        )
    }

    /// 選取範圍可能比字還長（字剛被別處改短）：夾回字的範圍內，不越界。
    private static func clamped(_ selection: Range<Int>, count: Int) -> Range<Int> {
        let lower = min(max(selection.lowerBound, 0), count)
        let upper = min(max(selection.upperBound, lower), count)
        return lower ..< upper
    }

    /// 選取碰到的每一行的開頭。選取剛好停在下一行開頭，那一行不算。
    private static func lineStarts(
        in characters: [Character],
        covering selection: Range<Int>
    ) -> [Int] {
        var first = selection.lowerBound
        while first > 0, characters[first - 1] != "\n" {
            first -= 1
        }
        var starts = [first]
        let lastIncluded = selection.isEmpty ? selection.lowerBound : selection.upperBound - 1
        var index = first
        while index < lastIncluded {
            if characters[index] == "\n" {
                starts.append(index + 1)
            }
            index += 1
        }
        return starts
    }

    private static func hasMarker(
        _ marker: [Character],
        in characters: [Character],
        at offset: Int
    ) -> Bool {
        guard offset >= 0, offset + marker.count <= characters.count else {
            return false
        }
        return Array(characters[offset ..< offset + marker.count]) == marker
    }

    /// 原本第幾個字，改完變第幾個字。加在游標前面的往後推；拿掉的記號蓋到游標，游標停在那行開頭。
    private static func moved(_ offset: Int, by changes: [(start: Int, delta: Int)]) -> Int {
        var shift = 0
        for change in changes {
            if change.delta > 0 {
                if change.start <= offset {
                    shift += change.delta
                }
            } else if offset >= change.start - change.delta {
                shift += change.delta
            } else if offset > change.start {
                shift -= offset - change.start
            }
        }
        return offset + shift
    }
}
