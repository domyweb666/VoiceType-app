import UIKit

/// 新編輯框（試用）的 Markdown 樣子（2026-11-17，參考 MarkText 的做法）：
/// 標題變大變粗、`**粗體**` 變粗；游標不在那一行時，`#`、`**` 這些記號藏起來，游標進去才露出來。
/// 只改樣子不改字：存下來、複製出去的還是同一份純文字 Markdown（W5 的約定不變）。
/// 一次只算一行，打字時只重算改到的那幾行，不是整篇（長稿才不會越打越慢）。
/// 跟 v0.2.7 白畫面那版（commit 6e0a31a）的差別：不換字形、不碰 TextKit 1（不讀 layoutManager），
/// 只在字上設字型與顏色；注音選字中不動。
enum MarkdownLineStyle {
    enum Kind: Equatable {
        case heading(level: Int)
        case headingMarker
        case bold
        case boldMarker
        case listMarker
    }

    /// 一行裡的一段，位置是這一行裡的第幾格（UTF-16，跟 UITextView 一樣）。
    struct Span: Equatable {
        let kind: Kind
        let range: NSRange
    }

    static let maxHeadingLevel = DraftOutline.maxHeadingLevel
    private static let boldPattern = try? NSRegularExpression(pattern: "\\*\\*([^*\\n]+?)\\*\\*")

    /// 一行（不含換行）裡哪幾段要換樣子。標題的規則跟大綱一樣：`#` 到 `######` 後面接空白。
    static func spans(inLine line: String) -> [Span] {
        let length = (line as NSString).length
        var spans: [Span] = []
        let level = line.prefix { $0 == "#" }.count
        if (1 ... maxHeadingLevel).contains(level), line.dropFirst(level).first == " " {
            let marker = NSRange(location: 0, length: level + 1)
            spans.append(Span(kind: .headingMarker, range: marker))
            spans.append(Span(
                kind: .heading(level: level),
                range: NSRange(location: level + 1, length: length - level - 1)
            ))
        } else if line.hasPrefix(MarkdownFormatting.listPrefix) {
            let prefix = MarkdownFormatting.listPrefix as NSString
            let marker = NSRange(location: 0, length: prefix.length)
            spans.append(Span(kind: .listMarker, range: marker))
        }
        let matches = boldPattern?.matches(
            in: line,
            range: NSRange(location: 0, length: length)
        ) ?? []
        for match in matches {
            let whole = match.range
            let inner = match.range(at: 1)
            spans.append(Span(
                kind: .boldMarker,
                range: NSRange(location: whole.location, length: inner.location - whole.location)
            ))
            spans.append(Span(kind: .bold, range: inner))
            let closing = NSMaxRange(inner)
            spans.append(Span(
                kind: .boldMarker,
                range: NSRange(location: closing, length: NSMaxRange(whole) - closing)
            ))
        }
        return spans
    }

    /// 選取或游標碰到這一行（含行尾）就算「在這一行」：記號要露出來，才知道自己在改什麼。
    static func isActive(line: NSRange, selection: NSRange?) -> Bool {
        guard let selection else {
            return false
        }
        return selection.location <= NSMaxRange(line) && NSMaxRange(selection) >= line.location
    }
}

/// 把上面算出來的樣子套到編輯框的字上。
extension MarkdownLineStyle {
    /// 重算 `range` 碰到的每一行。`selection` 是 nil（沒在打字）時，每一行的記號都藏起來。
    static func apply(
        to storage: NSTextStorage,
        around range: NSRange,
        selection: NSRange?,
        base: [NSAttributedString.Key: Any]
    ) {
        let text = storage.string as NSString
        guard text.length > 0 else {
            return
        }
        let location = min(max(0, range.location), text.length)
        let length = min(max(0, range.length), text.length - location)
        let paragraphs = text.paragraphRange(for: NSRange(location: location, length: length))
        storage.beginEditing()
        storage.setAttributes(base, range: paragraphs)
        text.enumerateSubstrings(in: paragraphs, options: .byParagraphs) { line, lineRange, _, _ in
            guard let line, !line.isEmpty else {
                return
            }
            let isActive = isActive(line: lineRange, selection: selection)
            for span in spans(inLine: line) where span.range.length > 0 {
                let target = NSRange(
                    location: lineRange.location + span.range.location,
                    length: span.range.length
                )
                storage.addAttributes(attributes(for: span.kind, isActive: isActive), range: target)
            }
        }
        storage.endEditing()
    }

    /// 藏起來的記號：透明、縮到幾乎沒有寬度。字還在，游標移得過去，存檔照樣有。
    private static var hiddenMarker: [NSAttributedString.Key: Any] {
        [
            .foregroundColor: UIColor.clear,
            .font: UIFont.systemFont(ofSize: hiddenMarkerSize),
        ]
    }

    private static let hiddenMarkerSize: CGFloat = 0.1

    private static func attributes(
        for kind: Kind,
        isActive: Bool
    ) -> [NSAttributedString.Key: Any] {
        let body = UIFont.preferredFont(forTextStyle: .body)
        let marker = UIColor(Token.Colors.textTertiary)
        switch kind {
        case let .heading(level):
            return [.font: headingFont(level: level)]
        case .bold:
            return [.font: bold(body)]
        case .headingMarker, .boldMarker:
            return isActive ? [.foregroundColor: marker] : hiddenMarker
        case .listMarker:
            // 清單的「- 」不藏：藏了就看不出是清單，只淡一點。
            return [.foregroundColor: UIColor(Token.Colors.textSecondary)]
        }
    }

    /// 一級標題最大，三級以下跟粗的正文差不多大。都跟著系統字級走。
    private static func headingFont(level: Int) -> UIFont {
        let styles: [UIFont.TextStyle] = [.title2, .title3]
        let style = level <= styles.count ? styles[level - 1] : .headline
        return bold(UIFont.preferredFont(forTextStyle: style))
    }

    private static func bold(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
