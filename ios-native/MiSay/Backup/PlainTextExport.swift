import Foundation

/// 把文字稿的 Markdown 變成乾淨的純文字（2026-11-24 Y1）：貼到 Threads、IG、LINE 不會留下 `#`、`**`。
/// 沒有記號的字一個都不動。
enum PlainTextExport {
    static let bullet = "・"
    /// 三個以上連著的換行（中間只有空白也算）。
    private static let extraBlankLines = "\\n(?:[ \\t\u{3000}]*\\n){2,}"

    static func text(from markdown: String) -> String {
        MarkdownLine.lines(of: markdown)
            .map { plainLine($0) }
            .joined(separator: "\n")
            .replacingOccurrences(
                of: extraBlankLines,
                with: "\n\n",
                options: .regularExpression
            )
    }

    private static func plainLine(_ raw: String) -> String {
        switch MarkdownLine.parse(raw) {
        case .blank:
            return raw
        case let .heading(_, text), let .paragraph(text):
            return plainText(MarkdownInline.parse(text))
        case let .item(leading, number, text):
            let mark = number.map { $0 + ". " } ?? bullet
            return leading + mark + plainText(MarkdownInline.parse(text))
        case let .quote(text):
            // 引用裡面可能還有清單或再一層引用。
            return plainLine(text)
        }
    }

    private static func plainText(_ pieces: [MarkdownInline]) -> String {
        pieces.map { piece -> String in
            switch piece {
            case let .text(text), let .code(text):
                return text
            case let .strong(inner), let .emphasis(inner):
                return plainText(inner)
            case let .link(label, destination):
                let text = plainText(label)
                return text == destination ? text : "\(text)（\(destination)）"
            }
        }
        .joined()
    }
}
