import Foundation

/// 把文字稿的 Markdown 變成乾淨的純文字（2026-11-24 Y1）：貼到 Threads、IG、LINE 不會留下 `#`、`**`。
/// 沒有記號的字一個都不動。
enum PlainTextExport {
    static let bullet = "・"
    /// 預覽給這麼多字就夠兩三行，畫面自己再截。
    static let openingLength = 200
    /// 預覽只轉開頭這麼多字：去掉記號會變短，連結的網址也佔字，要比預覽多留一些。
    private static let openingSourceLength = 400
    private static let strongMark = "**"
    /// 切在網址中間的連結：只剩開頭，認不出來是連結。
    private static let cutLink = #"\[([^\[\]\n]+)\]\((?:[!-'*-~]|\([!-'*-~]*\))*\(?[!-'*-~]*$"#
    /// 三個以上連著的換行（中間只有空白也算）。
    private static let extraBlankLines = "\\n(?:[ \\t\u{3000}]*\\n){2,}"

    static func text(from markdown: String) -> String {
        text(from: markdown, showsURLs: true)
    }

    private static func text(from markdown: String, showsURLs: Bool) -> String {
        MarkdownLine.lines(of: markdown)
            .map { plainLine($0, showsURLs: showsURLs) }
            .joined(separator: "\n")
            .replacingOccurrences(
                of: extraBlankLines,
                with: "\n\n",
                options: .regularExpression
            )
    }

    /// 列表上的預覽：開頭那幾個字，去掉記號，連結只留字不露網址。長稿只轉開頭一小段，不整篇轉。
    static func opening(of markdown: String, limit: Int = openingLength) -> String {
        let body = markdown.drop(while: \.isWhitespace)
        let head = body.prefix(max(limit, openingSourceLength))
        let isCut = head.endIndex < body.endIndex
        let source = isCut ? closingMarks(head) : String(head)
        let plain = text(from: source, showsURLs: false)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(plain.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 切在連結中間：只留連結的字。切在一長段粗體中間：補上收尾的記號，開頭那個才認得出來、才去得掉。
    private static func closingMarks(_ head: Substring) -> String {
        let text = String(head).replacingOccurrences(
            of: cutLink,
            with: "$1",
            options: .regularExpression
        )
        let lastLine = MarkdownLine.lines(of: text).last ?? ""
        let markCount = lastLine.components(separatedBy: strongMark).count - 1
        return markCount.isMultiple(of: 2) ? text : text + strongMark
    }

    private static func plainLine(_ raw: String, showsURLs: Bool) -> String {
        switch MarkdownLine.parse(raw) {
        case .blank:
            return raw
        case let .heading(_, text), let .paragraph(text):
            return plainText(MarkdownInline.parse(text), showsURLs: showsURLs)
        case let .item(leading, number, text):
            let mark = number.map { $0 + ". " } ?? bullet
            return leading + mark + plainText(MarkdownInline.parse(text), showsURLs: showsURLs)
        case let .quote(text):
            // 引用裡面可能還有清單或再一層引用。
            return plainLine(text, showsURLs: showsURLs)
        }
    }

    private static func plainText(_ pieces: [MarkdownInline], showsURLs: Bool) -> String {
        pieces.map { piece -> String in
            switch piece {
            case let .text(text), let .code(text):
                return text
            case let .strong(inner), let .emphasis(inner):
                return plainText(inner, showsURLs: showsURLs)
            case let .link(label, destination):
                let text = plainText(label, showsURLs: showsURLs)
                return !showsURLs || text == destination ? text : "\(text)（\(destination)）"
            }
        }
        .joined()
    }
}
