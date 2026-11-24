import Foundation

/// 把文字稿的 Markdown 變成一小段 HTML（2026-11-24 Y1），只放進剪貼簿，貼到能排版的地方粗體與標題才跟得過去。
/// App 裡不渲染它（安全標準五）。內容一律跳脫，連結只准 http／https，其他的照字面寫出來。
enum HTMLExport {
    /// 清單的一列。`depth` 是縮排幾格，多的排在少的底下。
    private struct Item {
        let depth: Int
        let number: String?
        let text: String
    }

    private static let tabWidth = 4
    private static let allowedSchemes = ["http", "https"]

    static func html(from markdown: String) -> String {
        let lines = MarkdownLine.lines(of: markdown).map { MarkdownLine.parse($0) }
        var html = ""
        var index = 0
        while index < lines.count {
            switch lines[index] {
            case .blank:
                index += 1
            case let .heading(level, text):
                html += heading(level: level, text: text)
                index += 1
            case .paragraph:
                let texts = run(in: lines, from: index, text: paragraphText)
                let inner = texts.map { inline($0) }.joined(separator: "<br>")
                html += "<p>" + inner + "</p>"
                index += texts.count
            case .quote:
                let texts = run(in: lines, from: index, text: quoteText)
                let inner = Self.html(from: texts.joined(separator: "\n"))
                html += "<blockquote>" + inner + "</blockquote>"
                index += texts.count
            case .item:
                let found = items(in: lines, from: index)
                html += list(found.items[...])
                index = found.end
            }
        }
        return html
    }

    /// 從 `start` 起連著幾行同一種的字。
    private static func run(
        in lines: [MarkdownLine],
        from start: Int,
        text: (MarkdownLine) -> String?
    ) -> [String] {
        var texts: [String] = []
        for line in lines[start...] {
            guard let found = text(line) else {
                break
            }
            texts.append(found)
        }
        return texts
    }

    private static func paragraphText(_ line: MarkdownLine) -> String? {
        guard case let .paragraph(text) = line else {
            return nil
        }
        return text
    }

    private static func quoteText(_ line: MarkdownLine) -> String? {
        guard case let .quote(text) = line else {
            return nil
        }
        return text
    }

    /// 連著的清單。項目中間空一行還是同一份，AI 常這樣寫。
    private static func items(
        in lines: [MarkdownLine],
        from start: Int
    ) -> (items: [Item], end: Int) {
        var items: [Item] = []
        var end = start
        for index in start ..< lines.count {
            if case let .item(leading, number, text) = lines[index] {
                let depth = leading.reduce(0) { $0 + ($1 == "\t" ? tabWidth : 1) }
                items.append(Item(depth: depth, number: number, text: text))
                end = index + 1
            } else if lines[index] != .blank {
                break
            }
        }
        return (items, end)
    }

    private static func list(_ items: ArraySlice<Item>) -> String {
        var html = ""
        var openTag: String?
        var index = items.startIndex
        while index < items.endIndex {
            let item = items[index]
            let tag = item.number == nil ? "ul" : "ol"
            if tag != openTag {
                html += closing(openTag) + opening(tag, number: item.number)
                openTag = tag
            }
            var next = index + 1
            while next < items.endIndex, items[next].depth > item.depth {
                next += 1
            }
            html += "<li>" + inline(item.text) + list(items[index + 1 ..< next]) + "</li>"
            index = next
        }
        return html + closing(openTag)
    }

    /// 被一段話隔開的「2.」要接著數，不能又從 1 開始。
    private static func opening(_ tag: String, number: String?) -> String {
        guard let start = number.flatMap({ Int($0) }), start != 1 else {
            return "<\(tag)>"
        }
        return "<\(tag) start=\"\(start)\">"
    }

    private static func closing(_ tag: String?) -> String {
        tag.map { "</\($0)>" } ?? ""
    }

    /// 文章的大標在別的平台另外填，內文最大用到 h2，三級以下都是 h3。
    private static func heading(level: Int, text: String) -> String {
        guard !text.isEmpty else {
            return ""
        }
        let tag = level <= 2 ? "h2" : "h3"
        return "<\(tag)>" + inline(text) + "</\(tag)>"
    }

    private static func inline(_ text: String) -> String {
        inlineHTML(MarkdownInline.parse(text))
    }

    private static func inlineHTML(_ pieces: [MarkdownInline]) -> String {
        pieces.map { piece -> String in
            switch piece {
            case let .text(text), let .code(text):
                return escaped(text)
            case let .strong(inner):
                return "<strong>" + inlineHTML(inner) + "</strong>"
            case let .emphasis(inner):
                return inlineHTML(inner)
            case let .link(label, destination):
                guard isAllowed(destination) else {
                    return inlineHTML(label) + "（" + escaped(destination) + "）"
                }
                return "<a href=\"\(escaped(destination))\">" + inlineHTML(label) + "</a>"
            }
        }
        .joined()
    }

    private static func isAllowed(_ destination: String) -> Bool {
        let scheme = destination.prefix { $0 != ":" }
        let isWebAddress = destination.dropFirst(scheme.count).hasPrefix("://")
        return isWebAddress && allowedSchemes.contains(scheme.lowercased())
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
