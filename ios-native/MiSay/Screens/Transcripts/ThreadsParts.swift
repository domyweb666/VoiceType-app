import Foundation

/// 把「1/」「2/」開頭的串文拆成幾篇，一篇一篇複製去貼（2026-11-24 Y1；Y5 接到畫面）。
/// 拆開只是分堆，字一個都不少：「1/」留著，第一篇之前的話併進第一篇。
enum ThreadsParts {
    /// Threads 一篇的上限。
    static let characterLimit = 500

    struct Part: Equatable, Identifiable {
        let number: Int
        let markdown: String
        /// 貼出去的樣子：沒有 Markdown 記號。
        let text: String

        init(number: Int, markdown: String) {
            self.number = number
            self.markdown = markdown
            text = PlainTextExport.text(from: markdown)
        }

        var id: Int {
            number
        }

        /// 空白換行也算字數，平台是這樣算的。
        var characterCount: Int {
            text.unicodeScalars.count
        }

        var overflow: Int {
            max(0, characterCount - ThreadsParts.characterLimit)
        }
    }

    private struct Marker {
        let number: Int
        /// 「1/6」的 6；只寫「1/」是 nil。
        let total: Int?
    }

    /// AI 有時會寫成「**1/**」「## 1/」。「11/2026」這種不算。
    private static let markerPattern = try? NSRegularExpression(
        pattern: #"^(?:#{1,6} +)?(?:\*\*)?([0-9]{1,2})[/／]([0-9]{1,2})?(?![0-9])"#
    )
    private static let minimumParts = 2

    /// 分不出兩篇以上就整份當一篇；空的回空陣列。
    static func split(_ text: String) -> [Part] {
        var preamble: [String] = []
        var chunks: [[String]] = []
        var total: Int?
        for line in MarkdownLine.lines(of: text) {
            // 寫法要跟第一篇一樣：用「1/」分篇時，行首的「2/3 的人」是內文。
            let next = parseMarker(in: line).flatMap { marker in
                let isNext = marker.number == chunks.count + 1
                return isNext && (chunks.isEmpty || marker.total == total) ? marker : nil
            }
            if let next {
                total = next.total
                chunks.append([line])
                continue
            }
            if chunks.isEmpty {
                preamble.append(line)
            } else {
                chunks[chunks.count - 1].append(line)
            }
        }
        guard chunks.count >= minimumParts else {
            return parts(from: [text])
        }
        chunks[0] = preamble + chunks[0]
        return parts(from: chunks.map { $0.joined(separator: "\n") })
    }

    private static func parts(from texts: [String]) -> [Part] {
        texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { Part(number: $0.offset + 1, markdown: $0.element) }
    }

    private static func parseMarker(in line: String) -> Marker? {
        let source = line as NSString
        let whole = NSRange(location: 0, length: source.length)
        guard let match = markerPattern?.firstMatch(in: line, range: whole),
              let number = Int(source.substring(with: match.range(at: 1)))
        else {
            return nil
        }
        let totalRange = match.range(at: 2)
        guard totalRange.location != NSNotFound else {
            return Marker(number: number, total: nil)
        }
        return Marker(number: number, total: Int(source.substring(with: totalRange)))
    }
}
