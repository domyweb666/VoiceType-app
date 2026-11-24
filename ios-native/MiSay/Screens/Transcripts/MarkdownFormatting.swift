import Foundation

/// W5 文字稿的簡單格式（2026-11-09）：鍵盤上方那一排（`FormatBar`）。文字稿還是純文字，
/// 只是插入 Markdown 記號，存成 Markdown 時照原樣出去，Obsidian 直接看得懂。不做富文字編輯器。
/// 位置一律用第幾個字（Character），改完的字是新的字串，舊的 String.Index 不能再用。
enum MarkdownFormatting {
    struct Edit: Equatable {
        let text: String
        /// 改完之後游標或選取範圍在哪（第幾個字）。
        let selection: Range<Int>
    }

    /// 放在一行開頭的記號。一行只放一種，換別種就換掉，不疊上去（2026-11-24 Y4）。
    enum LineMark: CaseIterable, Identifiable {
        case heading
        case subheading
        case list
        case numbered
        case quote

        var id: Self {
            self
        }
    }

    /// 一行開頭原本的記號：是哪一種（別的標題層級、沒有記號都是 nil）、佔幾個字。
    struct Marker {
        let mark: LineMark?
        let length: Int
        /// 記號前面縮了幾個字。沒有記號的行算 0，縮排當成內文。
        var indent = 0
    }

    /// 從 `start` 開始的記號，原本佔幾個字、換成哪幾個字。
    struct Change {
        let start: Int
        let removed: Int
        let inserted: [Character]
    }

    static let headingPrefix = "## "
    static let subheadingPrefix = "### "
    static let listPrefix = "- "
    static let quotePrefix = "> "
    static let boldMarker = "**"
    private static let maxNumberDigits = 3
    private static let linkSchemes = ["http", "https"]

    /// 選到的每一行（沒選就是游標那一行）開頭加記號；全部都已經是這種就拿掉。
    /// 選好幾行時空行不加；編號照順序 1. 2. 3.。
    static func toggle(_ mark: LineMark, in text: String, selection: Range<Int>) -> Edit {
        var characters = Array(text)
        let selection = clamped(selection, count: characters.count)
        let starts = markableStarts(in: characters, covering: selection)
        let markers = starts.map { marker(in: characters, at: $0) }
        let isRemoving = markers.allSatisfy { $0.mark == mark }
        // 標題不縮排，換成標題時縮排一起拿掉。
        let dropsIndent = !isRemoving && (mark == .heading || mark == .subheading)
        let changes = starts.indices.map { index in
            let marker = markers[index]
            return Change(
                start: starts[index] + (dropsIndent ? 0 : marker.indent),
                removed: marker.length + (dropsIndent ? marker.indent : 0),
                inserted: isRemoving ? [] : Array(prefix(for: mark, order: index + 1))
            )
        }
        // 從後面改回來，前面的位置才不會跑掉。
        for change in changes.reversed() {
            let old = change.start ..< change.start + change.removed
            characters.replaceSubrange(old, with: change.inserted)
        }
        let lower = moved(selection.lowerBound, by: changes)
        let upper = moved(selection.upperBound, by: changes)
        return Edit(text: String(characters), selection: lower ..< upper)
    }

    /// 選到的字變成 `[字](網址)`；沒選字就放網址。選到的字跨行或有方括號，包起來會壞掉，網址放在後面。
    static func addLink(_ url: String, in text: String, selection: Range<Int>) -> Edit {
        var characters = Array(text)
        let selection = clamped(selection, count: characters.count)
        let label = String(characters[selection])
        let breaksLabel = label.contains { $0.isNewline || $0 == "[" || $0 == "]" }
        let wrapsLabel = !label.isEmpty && !breaksLabel
        let link = Array(wrapsLabel ? "[\(label)](\(url))" : url)
        let start = wrapsLabel ? selection.lowerBound : selection.upperBound
        characters.replaceSubrange(start ..< selection.upperBound, with: link)
        let end = start + link.count
        return Edit(text: String(characters), selection: end ..< end)
    }

    /// 打進來的網址：沒寫開頭的補 https；不是 http／https、沒有網站名、中間有空白的不收，回 nil。
    /// 括號換成編碼：Markdown 的網址是用括號包的。
    static func linkURL(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else {
            return nil
        }
        let hasScheme = trimmed.contains("://")
        let looksLikeSite = trimmed.contains(".") && !trimmed.contains(":")
        guard hasScheme || looksLikeSite else {
            return nil
        }
        let whole = hasScheme ? trimmed : "https://" + trimmed
        guard let url = URL(string: whole), let scheme = url.scheme?.lowercased(),
              linkSchemes.contains(scheme), let host = url.host(), !host.isEmpty
        else {
            return nil
        }
        return whole.replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
    }

    static func prefix(for mark: LineMark, order: Int) -> String {
        switch mark {
        case .heading: headingPrefix
        case .subheading: subheadingPrefix
        case .list: listPrefix
        case .numbered: "\(order). "
        case .quote: quotePrefix
        }
    }

    /// 這一行開頭的編號（「1. 」）佔幾個字；不是編號是 nil。超過三位數的多半是年份，不算（跟匯出同一條規則）。
    static func numberedLength(of line: some Sequence<Character>) -> Int? {
        let head = Array(line.prefix(maxNumberDigits + 2))
        let digits = head.prefix { $0.isASCII && $0.isNumber }.count
        guard (1 ... maxNumberDigits).contains(digits), head.count >= digits + 2,
              head[digits] == ".", head[digits + 1] == " "
        else {
            return nil
        }
        return digits + 2
    }

    /// 選取範圍可能比字還長（字剛被別處改短）：夾回字的範圍內，不越界。
    static func clamped(_ selection: Range<Int>, count: Int) -> Range<Int> {
        let lower = min(max(selection.lowerBound, 0), count)
        let upper = min(max(selection.upperBound, lower), count)
        return lower ..< upper
    }

    /// 選取碰到的每一行的開頭。選取剛好停在下一行開頭，那一行不算。
    static func lineStarts(
        in characters: [Character],
        covering selection: Range<Int>
    ) -> [Int] {
        var first = selection.lowerBound
        while first > 0, !characters[first - 1].isNewline {
            first -= 1
        }
        var starts = [first]
        let lastIncluded = selection.isEmpty ? selection.lowerBound : selection.upperBound - 1
        var index = first
        while index < lastIncluded {
            if characters[index].isNewline {
                starts.append(index + 1)
            }
            index += 1
        }
        return starts
    }

    /// 選好幾行時跳過空行；全部都是空行就照原樣。
    private static func markableStarts(
        in characters: [Character],
        covering selection: Range<Int>
    ) -> [Int] {
        let starts = lineStarts(in: characters, covering: selection)
        let written = starts.filter { $0 < characters.count && !characters[$0].isNewline }
        return written.isEmpty ? starts : written
    }

    /// 縮排的清單也認得出記號（「  - 乙」），不然再按一次會疊上去。
    static func marker(in characters: [Character], at start: Int) -> Marker {
        let line = characters[start...].prefix { !$0.isNewline }
        let indent = line.prefix { $0 == " " || $0 == "\t" }.count
        let found = marker(of: line.dropFirst(indent))
        guard found.length > 0 else {
            return found
        }
        return Marker(mark: found.mark, length: found.length, indent: indent)
    }

    private static func marker(of line: ArraySlice<Character>) -> Marker {
        let level = line.prefix { $0 == "#" }.count
        let isHeading = (1 ... DraftOutline.maxHeadingLevel).contains(level)
        if isHeading, line.dropFirst(level).first == " " {
            let known = [headingPrefix: LineMark.heading, subheadingPrefix: LineMark.subheading]
            return Marker(mark: known[String(line.prefix(level + 1))], length: level + 1)
        }
        if line.starts(with: listPrefix) {
            return Marker(mark: .list, length: listPrefix.count)
        }
        if line.starts(with: quotePrefix) {
            return Marker(mark: .quote, length: quotePrefix.count)
        }
        if let length = numberedLength(of: line) {
            return Marker(mark: .numbered, length: length)
        }
        return Marker(mark: nil, length: 0)
    }

    static func hasMarker(
        _ marker: [Character],
        in characters: [Character],
        at offset: Int
    ) -> Bool {
        guard offset >= 0, offset + marker.count <= characters.count else {
            return false
        }
        return Array(characters[offset ..< offset + marker.count]) == marker
    }

    /// 原本第幾個字，改完變第幾個字。加在游標前面的往後推；游標在被換掉的記號裡，就停在新記號後面
    /// （拿掉的話就是那行開頭）。
    static func moved(_ offset: Int, by changes: [Change]) -> Int {
        var shift = 0
        for change in changes {
            if offset >= change.start + change.removed {
                shift += change.inserted.count - change.removed
            } else if offset > change.start {
                shift += change.inserted.count - (offset - change.start)
            }
        }
        return offset + shift
    }
}
