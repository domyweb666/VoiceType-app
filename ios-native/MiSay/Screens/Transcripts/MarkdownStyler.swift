import UIKit

/// 編輯框邊打邊變樣（2026-11-09 米：按了標題，字要直接變成標題的樣子，不是看到 `## 原字`）。
/// 字一個都不改，存的還是 Markdown，只換畫面上的樣子：記號變淡、標題那行變大變粗、`**` 中間變粗，
/// 清單開頭的 `-` 由編輯框畫成圓點（`MarkdownTextView`）。
/// 一行一行算：標題、清單都是整行的事，粗體也只認同一行裡成對的 `**`。位置一律用 UTF-16（跟 NSString 一樣）。
enum MarkdownStyler {
    enum Role: Equatable {
        case headingMarker
        case headingText
        case listMarker
        case boldMarker
        case boldText
    }

    struct Run: Equatable {
        let role: Role
        /// 在這一行裡的位置。
        let range: NSRange
    }

    /// 標題最多幾個 `#`（Markdown 只有到六級）。
    static let maxHeadingLevel = 6

    private static let hash: unichar = 0x23 // #
    private static let space: unichar = 0x20
    private static let hyphen: unichar = 0x2D // -
    private static let newline: unichar = 0x0A

    /// 一行（不含換行）裡哪些字要換樣子。
    static func runs(in line: NSString) -> [Run] {
        var runs: [Run] = []
        let markerLength = headingMarkerLength(of: line)
        if markerLength > 0 {
            let marker = NSRange(location: 0, length: markerLength)
            runs.append(Run(role: .headingMarker, range: marker))
            if line.length > markerLength {
                let text = NSRange(location: markerLength, length: line.length - markerLength)
                runs.append(Run(role: .headingText, range: text))
            }
        } else if isListMarker(at: 0, in: line) {
            runs.append(Run(role: .listMarker, range: NSRange(location: 0, length: 1)))
        }
        return runs + boldRuns(in: line)
    }

    /// 這個位置的 `-` 是不是清單開頭：在行首，後面接一個空白。編輯框畫圓點時一個字一個字問。
    static func isListMarker(at index: Int, in string: NSString) -> Bool {
        guard index >= 0, index + 1 < string.length,
              string.character(at: index) == hyphen,
              string.character(at: index + 1) == space
        else {
            return false
        }
        return index == 0 || string.character(at: index - 1) == newline
    }

    /// 改到的那幾行重新上樣式：先全部回到正文，再照 `runs` 一段一段換。
    static func apply(to storage: NSTextStorage, around range: NSRange) {
        let string = storage.string as NSString
        // 不用 NSIntersectionRange：刪掉最後一個字時改到的範圍停在最末端、長度 0，它會回 {0, 0}，改成重上第一行。
        let location = min(max(0, range.location), string.length)
        let length = min(max(0, range.length), string.length - location)
        let clamped = NSRange(location: location, length: length)
        let paragraphs = string.paragraphRange(for: clamped)
        storage.setAttributes(baseAttributes, range: paragraphs)
        string.enumerateSubstrings(
            in: paragraphs,
            options: [.byParagraphs, .substringNotRequired]
        ) { _, lineRange, _, _ in
            let lineRuns = Self.runs(in: string.substring(with: lineRange) as NSString)
            let isHeading = lineRuns.contains { $0.role == .headingMarker }
            for run in lineRuns {
                let target = NSRange(
                    location: lineRange.location + run.range.location,
                    length: run.range.length
                )
                storage.addAttributes(
                    Self.attributes(for: run.role, inHeading: isHeading),
                    range: target
                )
            }
            if lineRuns.contains(where: { $0.role == .listMarker }) {
                let style = Self.listParagraphStyle
                storage.addAttribute(.paragraphStyle, value: style, range: lineRange)
            }
        }
    }

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: Token.Editor.body,
            .foregroundColor: Token.Editor.textPrimary,
            .paragraphStyle: paragraphStyle(headIndent: 0),
        ]
    }

    private static func attributes(
        for role: Role,
        inHeading: Bool
    ) -> [NSAttributedString.Key: Any] {
        switch role {
        case .headingMarker:
            [.font: Token.Editor.marker, .foregroundColor: Token.Editor.textSecondary]
        case .headingText:
            [.font: Token.Editor.heading]
        case .listMarker, .boldMarker:
            [.foregroundColor: Token.Editor.textSecondary]
        case .boldText:
            // 標題那行本來就粗，不用再換字型。
            inHeading ? [:] : [.font: Token.Editor.bold(Token.Editor.body)]
        }
    }

    /// 清單折到第二行時對齊圓點後面的字，不要縮回行首。
    private static var listParagraphStyle: NSParagraphStyle {
        let bulletWidth = ("• " as NSString).size(withAttributes: [.font: Token.Editor.body]).width
        return paragraphStyle(headIndent: bulletWidth)
    }

    private static func paragraphStyle(headIndent: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Token.Space.lineSpacing
        style.headIndent = headIndent
        return style
    }

    /// `## ` 這種開頭有幾個字（含空白）；不是標題回 0。
    private static func headingMarkerLength(of line: NSString) -> Int {
        var count = 0
        while count < line.length, count < maxHeadingLevel, line.character(at: count) == hash {
            count += 1
        }
        guard count > 0, count < line.length, line.character(at: count) == space else {
            return 0
        }
        return count + 1
    }

    /// 同一行裡成對的 `**`：第一個開、下一個關，中間沒有字的不算。
    private static func boldRuns(in line: NSString) -> [Run] {
        var runs: [Run] = []
        var searchStart = 0
        while searchStart < line.length {
            let open = line.range(
                of: MarkdownFormatting.boldMarker,
                range: NSRange(location: searchStart, length: line.length - searchStart)
            )
            guard open.location != NSNotFound else {
                break
            }
            let afterOpen = NSMaxRange(open)
            let close = line.range(
                of: MarkdownFormatting.boldMarker,
                range: NSRange(location: afterOpen, length: line.length - afterOpen)
            )
            guard close.location != NSNotFound else {
                break
            }
            if close.location > afterOpen {
                let text = NSRange(location: afterOpen, length: close.location - afterOpen)
                runs += [
                    Run(role: .boldMarker, range: open),
                    Run(role: .boldText, range: text),
                    Run(role: .boldMarker, range: close),
                ]
            }
            searchStart = NSMaxRange(close)
        }
        return runs
    }
}
