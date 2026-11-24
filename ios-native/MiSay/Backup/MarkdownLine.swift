import Foundation

/// 一行 Markdown 是什麼（複製成純文字與 HTML 共用，2026-11-24 Y1）。
/// 記號後面要有空白才算，「#標籤」「C#」「-5 度」「3.14」都是一般的字。
enum MarkdownLine: Equatable {
    case blank
    case heading(level: Int, text: String)
    /// `leading` 是前面縮排的空白；`number` 是原本寫的號碼，nil 是沒有號碼的清單。
    case item(leading: String, number: String?, text: String)
    case quote(String)
    case paragraph(String)

    private static let bulletPrefixes = [MarkdownFormatting.listPrefix, "* "]
    private static let quoteMark = ">"
    private static let numberSuffix = ". "
    /// 超過三位數的多半是年份（「2026. 」），不當清單。
    private static let maxNumberDigits = 3

    /// 從別處貼進來的字可能是 Windows 的換行。
    static func lines(of text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    }

    static func parse(_ line: String) -> MarkdownLine {
        guard !line.allSatisfy(\.isWhitespace) else {
            return .blank
        }
        let level = line.prefix { $0 == "#" }.count
        let isHeading = (1 ... DraftOutline.maxHeadingLevel).contains(level)
        if isHeading, line.dropFirst(level).first == " " {
            let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
            return .heading(level: level, text: text)
        }
        let leading = String(line.prefix { $0 == " " || $0 == "\t" })
        let body = String(line.dropFirst(leading.count))
        if let prefix = bulletPrefixes.first(where: { body.hasPrefix($0) }) {
            let text = String(body.dropFirst(prefix.count))
            return .item(leading: leading, number: nil, text: text)
        }
        let digits = String(body.prefix { $0.isASCII && $0.isNumber })
        let rest = String(body.dropFirst(digits.count))
        let isNumbered = (1 ... maxNumberDigits).contains(digits.count)
        if isNumbered, rest.hasPrefix(numberSuffix) {
            let text = String(rest.dropFirst(numberSuffix.count))
            return .item(leading: leading, number: digits, text: text)
        }
        if body == quoteMark || body.hasPrefix(quoteMark + " ") {
            return .quote(String(body.dropFirst(quoteMark.count + 1)))
        }
        return .paragraph(line)
    }
}
