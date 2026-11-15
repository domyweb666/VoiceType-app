import Foundation

/// 2026-11-15：五千字在手機上要滑三十幾個畫面。大綱照標題（沒有標題就照段落）列出來，點了跳過去；
/// 尋找列出這篇裡每一處。位置都是第幾個字（Character），給編輯框放游標（純函式，CI 測得到）。
enum DraftOutline {
    struct Entry: Equatable, Identifiable {
        /// 從第幾個字開始。同一份清單裡不會重複，直接當 id。
        let offset: Int
        /// 要選起來的長度；大綱只放游標是 0，尋找是找到的那幾個字。
        let length: Int
        let title: String
        /// 標題的層級（幾個 #），段落與尋找都是 1。
        let level: Int

        var id: Int {
            offset
        }

        var range: Range<Int> {
            offset ..< offset + length
        }
    }

    static let maxHeadingLevel = 6
    static let previewLength = 28
    static let leadingContext = 10
    static let maxMatches = 200

    /// `# ` 到 `###### ` 開頭的行。
    static func headings(in text: String) -> [Entry] {
        lines(of: text).compactMap { offset, line in
            let level = line.prefix { $0 == "#" }.count
            let rest = line.dropFirst(level)
            guard (1 ... maxHeadingLevel).contains(level), rest.first == " " else {
                return nil
            }
            let title = rest.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else {
                return nil
            }
            return Entry(offset: offset, length: 0, title: title, level: level)
        }
    }

    /// 沒有標題時用：每一段開頭的幾個字。
    static func paragraphs(in text: String) -> [Entry] {
        lines(of: text).compactMap { offset, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                return nil
            }
            let title = String(trimmed.prefix(previewLength))
            return Entry(offset: offset, length: 0, title: title, level: 1)
        }
    }

    /// 這篇裡每一處（不分大小寫），最多 `maxMatches` 處。標題是那一處前後的幾個字。
    static func matches(of query: String, in text: String) -> [Entry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var entries: [Entry] = []
        var searchStart = text.startIndex
        var offset = 0
        while !needle.isEmpty, entries.count < maxMatches {
            let rest = searchStart ..< text.endIndex
            guard let found = text.range(of: needle, options: .caseInsensitive, range: rest),
                  !found.isEmpty
            else {
                break
            }
            offset += text.distance(from: searchStart, to: found.lowerBound)
            let length = text.distance(from: found.lowerBound, to: found.upperBound)
            let title = preview(around: found, in: text)
            entries.append(Entry(offset: offset, length: length, title: title, level: 1))
            offset += length
            searchStart = found.upperBound
        }
        return entries
    }

    private static func preview(around found: Range<String.Index>, in text: String) -> String {
        let first = text.startIndex
        let start = text.index(found.lowerBound, offsetBy: -leadingContext, limitedBy: first)
            ?? first
        let end = text.index(start, offsetBy: previewLength, limitedBy: text.endIndex)
            ?? text.endIndex
        return String(text[start ..< max(end, found.upperBound)])
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// 每一行與它從第幾個字開始。
    private static func lines(of text: String) -> [(offset: Int, line: String)] {
        var result: [(offset: Int, line: String)] = []
        var offset = 0
        for line in text.components(separatedBy: "\n") {
            result.append((offset, line))
            offset += line.count + 1
        }
        return result
    }
}
