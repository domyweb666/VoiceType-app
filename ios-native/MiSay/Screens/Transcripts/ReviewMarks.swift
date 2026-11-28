import Foundation

/// 「請 AI 看整篇」R-C（2026-11-28 米選「意見標在稿子上」）：把唯讀的稿子切成段，算出哪幾個字要塗金、編號放哪。
/// 只算位置，畫在 `ReviewSheet+Manuscript`。位置跟 `ReviewResult.range(of:in:)` 一樣數「第幾個字」（Character），
/// 兩邊才對得上；兩處卡點引到同一句或疊在一起時，疊到的字算兩處都有，編號照順序各放一個。
enum ReviewMarks {
    /// 一處卡點在稿子上的位置。`number` 是托盤裡的第幾處（從 1 起）。
    struct Mark: Equatable {
        let number: Int
        let range: Range<Int>
        let isCurrent: Bool
    }

    enum Highlight: Equatable {
        case plain
        case marked
        /// 托盤正在講的那一處
        case current
    }

    enum Segment: Equatable {
        case text(String, Highlight)
        /// 卡點開頭前面那個編號
        case badge(Int, isCurrent: Bool)
    }

    /// 一段字（照換行切）。`id` 是第幾行（從 0 起，空行也算），捲動用它當錨點。
    struct Paragraph: Identifiable, Equatable {
        let id: Int
        let range: Range<Int>
        let segments: [Segment]
    }

    /// 空行不回傳（畫面用段距隔開），但位置照算，後面的段才對得上引文的位置。
    static func paragraphs(of text: String, marks: [Mark]) -> [Paragraph] {
        var result: [Paragraph] = []
        var start = 0
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() {
            let characters = Array(line)
            let range = start ..< start + characters.count
            start = range.upperBound + 1
            guard !characters.isEmpty else {
                continue
            }
            let pieces = segments(of: characters, in: range, marks: marks)
            result.append(Paragraph(id: index, range: range, segments: pieces))
        }
        return result
    }

    /// 要捲到哪一段：含那個字的段；那個字剛好在空行上，就往後找最近的一段。
    static func paragraphID(containing offset: Int, in paragraphs: [Paragraph]) -> Int? {
        paragraphs.first { $0.range.upperBound > offset }?.id
    }

    private static func segments(
        of characters: [Character],
        in paragraph: Range<Int>,
        marks: [Mark]
    ) -> [Segment] {
        let here = marks.filter { $0.range.overlaps(paragraph) }
        var cuts: Set<Int> = [paragraph.lowerBound, paragraph.upperBound]
        for mark in here {
            cuts.insert(max(mark.range.lowerBound, paragraph.lowerBound))
            cuts.insert(min(mark.range.upperBound, paragraph.upperBound))
        }
        let sortedCuts = cuts.sorted()
        var result: [Segment] = []
        for (lower, upper) in zip(sortedCuts, sortedCuts.dropFirst()) {
            let starting = here
                .filter { $0.range.lowerBound == lower }
                .sorted { $0.number < $1.number }
            result += starting.map { Segment.badge($0.number, isCurrent: $0.isCurrent) }
            let covering = here.filter { $0.range.contains(lower) }
            let offset = paragraph.lowerBound
            let slice = characters[(lower - offset) ..< (upper - offset)]
            result.append(.text(String(slice), highlight(for: covering)))
        }
        return result
    }

    private static func highlight(for covering: [Mark]) -> Highlight {
        if covering.contains(where: \.isCurrent) {
            return .current
        }
        return covering.isEmpty ? .plain : .marked
    }
}
