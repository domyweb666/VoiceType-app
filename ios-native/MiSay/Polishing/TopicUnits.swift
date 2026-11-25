import Foundation

/// 拆篇時文字稿切成的一小塊。字與後面的換行都照原稿留著，接得回去。
struct TopicUnit: Equatable {
    let text: String
    /// 原稿的第幾段，從 1 數，一行算一段。
    let paragraph: Int
    /// 中間沒有空行的算同一塊，例如一整串清單。
    let block: Int
    /// 原稿裡接在後面的換行與空行；切在一段中間的是空的。
    let separator: String
}

/// 片 J3 拆篇：文字稿怎麼切成編號的單位、怎麼照原稿接回來。
/// 模型只回段號，存的字全從這裡接，一個字都不會被改寫。
enum TopicUnits {
    /// 一段超過這麼多字才照句子切開：沒分段的長稿，一段裡可能講好幾件事。
    static let maxParagraphCharacters = 300
    static let targetCharacters = 150
    /// 只看全形：半形的問號、驚嘆號會切到網址與圖片連結中間。
    static let sentenceEnds: Set<Character> = ["。", "！", "？", "…"]
    /// 跟著句號走，不留在下一句的開頭。
    static let closingMarks: Set<Character> = ["」", "』", "）", "》", "】", "\u{201D}", "\u{2019}"]

    static func cut(_ text: String) -> [TopicUnit] {
        var units: [TopicUnit] = []
        var block = 0
        for (offset, paragraph) in paragraphs(of: text).enumerated() {
            let cutPieces = pieces(of: paragraph.line)
            for (index, piece) in cutPieces.enumerated() {
                let isLast = index == cutPieces.count - 1
                units.append(TopicUnit(
                    text: piece,
                    paragraph: offset + 1,
                    block: block,
                    separator: isLast ? paragraph.separator : ""
                ))
            }
            if paragraph.separator.filter(\.isNewline).count > 1 {
                block += 1
            }
        }
        return units
    }

    /// 送給模型的樣子，一個單位一行，前面是從 1 數的編號。
    static func numbered(_ units: [TopicUnit]) -> String {
        units.enumerated()
            .map { index, unit in "[\(index + 1)] \(unit.text)" }
            .joined(separator: "\n")
    }

    /// 照原稿的順序接回來。`indices` 從 0 數。
    static func join(_ indices: [Int], of units: [TopicUnit]) -> String {
        var text = ""
        var previous: Int?
        for index in indices.sorted() {
            if let previous {
                text += separator(from: previous, to: index, in: units)
            }
            text += units[index].text
            previous = index
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 本來就連著的照原稿；中間少了幾塊的，同一段直接相接，同一塊換行，其他空一行。
    private static func separator(
        from previous: Int,
        to index: Int,
        in units: [TopicUnit]
    ) -> String {
        let before = units[previous]
        let after = units[index]
        if index == previous + 1 {
            return before.separator
        }
        if before.paragraph == after.paragraph {
            return ""
        }
        return before.block == after.block ? "\n" : "\n\n"
    }

    /// 一行與它後面的換行；空行併進前一行的換行，開頭的空行丟掉。
    private static func paragraphs(of text: String) -> [(line: String, separator: String)] {
        var found: [(line: String, separator: String)] = []
        var rest = Substring(text)
        while !rest.isEmpty {
            let line = rest.prefix { !$0.isNewline }
            rest = rest[line.endIndex...]
            let newlines = rest.prefix { $0.isNewline }
            rest = rest[newlines.endIndex...]
            if !line.allSatisfy(\.isWhitespace) {
                found.append((line: String(line), separator: String(newlines)))
            } else if let last = found.indices.last {
                found[last].separator += String(line) + String(newlines)
            }
        }
        return found
    }

    private static func pieces(of line: String) -> [String] {
        guard line.count > maxParagraphCharacters else {
            return [line]
        }
        var found: [String] = []
        var current = ""
        for sentence in sentences(of: line) {
            current += sentence
            if current.count >= targetCharacters {
                found.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            found.append(current)
        }
        return found
    }

    private static func sentences(of line: String) -> [String] {
        var found: [String] = []
        var current = ""
        var hasEnded = false
        for character in line {
            let isEnd = sentenceEnds.contains(character)
            let isClosing = hasEnded && closingMarks.contains(character)
            if hasEnded, !isEnd, !isClosing {
                found.append(current)
                current = ""
            }
            current.append(character)
            hasEnded = isEnd || isClosing
        }
        if !current.isEmpty {
            found.append(current)
        }
        return found
    }
}
