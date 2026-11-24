import Foundation

/// 一行字裡的 Markdown 記號（複製成純文字與 HTML 共用，2026-11-24 Y1）。
/// 只認看得出是記號的：「2*3」「2**10」「王*明」「snake_case」要原樣留著，認錯會把使用者的字弄壞，
/// 所以拿不準的一律當成一般的字。
indirect enum MarkdownInline: Equatable {
    case text(String)
    case strong([MarkdownInline])
    case emphasis([MarkdownInline])
    case code(String)
    case link(label: [MarkdownInline], destination: String)

    /// 合起來那條樣式裡，各種記號是第幾個括號。
    private enum Group {
        static let code = 1
        static let label = 2
        static let destination = 3
        static let strongEmphasis = 4
        static let strong = 5
        static let emphasis = 6 ... 7
    }

    private static let codePattern = #"`([^`\n]+)`"#
    /// 網址要像網址（https 開頭，或一串英數字裡有點或冒號），「[註](見下)」才不會被當成連結。
    private static let linkPattern = #"\[([^\[\]\n]+)\]"#
        + #"\((?=https?://|[!-'*-~]*[.:])((?:[^\s()]|\([^\s()]*\))+)\)"#
    private static let strongEmphasisPattern = #"(?<!\*)\*\*\*([^*\n]+?)\*\*\*(?!\*)"#
    /// 前後都是數字的是乘冪；裡面兩頭都空白的是隔開的星號。
    private static let strongPattern = #"(?:(?<![0-9])|(?=\*\*[^0-9]))"#
        + #"\*\*(?!\s+\*\*)(?!\s[^*\n]*\s\*\*)([^*\n]+?)\*\*"#
    private static let emphasisInner = #"([^*\n]+?)(?<![\s\p{Ps}\p{Pi}])"#
    /// 斜體只有一顆星，跟乘號、遮字的星號長一樣：外側至少一邊要是空白、標點或行的頭尾才算。
    private static let emphasisAfterBoundary = #"(?<![\p{L}\p{N}*])"#
        + #"\*(?![\s*\p{Pe}\p{Pf}\p{Po}])"#
        + emphasisInner
        + #"(?:(?<![\p{P}\p{S}])|(?=\*(?![\p{L}\p{N}])))\*(?!\*)"#
    private static let emphasisBeforeBoundary = #"(?<=[\p{L}\p{N}])"#
        + #"(?:(?<![A-Za-z0-9])|(?=\*[^A-Za-z0-9]))\*(?![\s*\p{P}\p{S}])"#
        + emphasisInner
        + #"\*(?![\p{L}\p{N}*])"#

    /// 順序就是 `Group` 的編號。
    private static let pattern = try? NSRegularExpression(
        pattern: [
            codePattern,
            linkPattern,
            strongEmphasisPattern,
            strongPattern,
            emphasisAfterBoundary,
            emphasisBeforeBoundary,
        ].joined(separator: "|")
    )

    static func parse(_ text: String) -> [MarkdownInline] {
        let source = text as NSString
        let whole = NSRange(location: 0, length: source.length)
        var pieces: [MarkdownInline] = []
        var location = 0
        for match in pattern?.matches(in: text, range: whole) ?? [] {
            if match.range.location > location {
                let gap = NSRange(location: location, length: match.range.location - location)
                pieces.append(.text(source.substring(with: gap)))
            }
            pieces.append(piece(for: match, in: source))
            location = NSMaxRange(match.range)
        }
        if location < source.length {
            pieces.append(.text(source.substring(from: location)))
        }
        return pieces
    }

    private static func piece(
        for match: NSTextCheckingResult,
        in source: NSString
    ) -> MarkdownInline {
        func captured(_ group: Int) -> String? {
            let range = match.range(at: group)
            return range.location == NSNotFound ? nil : source.substring(with: range)
        }
        if let code = captured(Group.code) {
            return .code(code)
        }
        if let label = captured(Group.label), let destination = captured(Group.destination) {
            return .link(label: parse(label), destination: destination)
        }
        if let inner = captured(Group.strongEmphasis) ?? captured(Group.strong) {
            return .strong(parse(inner))
        }
        for group in Group.emphasis {
            if let inner = captured(group) {
                return .emphasis(parse(inner))
            }
        }
        return .text(source.substring(with: match.range))
    }
}
