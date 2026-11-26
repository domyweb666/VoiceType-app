import Foundation

/// 一處修改：改前、改後，加上改後那份前後各一小段字（拿來看改的是哪個詞）。
struct EditHunk: Equatable {
    let before: String
    let after: String
    let leading: String
    let trailing: String
}

/// 2026-11-08：拿「上次看到哪」的文字稿跟現在的比，找出人改過的地方（自動加入詞彙用）。
/// 用系統內建的比對（`difference(from:)`），長文也快；只在手機上算，不送任何地方。
/// 2026-11-25 起一個英文單字當一格、中文一個字一格：Cloud 改成 Claude 算改一處，不會拆成幾個字母。
enum EditDiff {
    /// 前後文各帶幾格。
    static let contextLength = 12
    /// 一段裡加掉的字超過這麼多就當整段重寫，不比：比對用的記憶體照改動量的平方長，
    /// 整篇一萬多字換掉會吃到 1 GB 以上，App 會被系統關掉。
    static let maxChangedUnits = 400
    static let maxComparedUnits = 8000

    /// 先一段一段比，只有改過的段才逐字比。
    static func hunks(from old: String, to new: String) -> [EditHunk] {
        changedParagraphs(from: old, to: new).flatMap { pair in
            paragraphHunks(from: units(of: pair.old), to: units(of: pair.new))
        }
    }

    /// 改過的那幾段，改前改後成對。連著改好幾段而且段數一樣就一段對一段，不一樣（拆段、併段）就整塊對整塊。
    private static func changedParagraphs(
        from old: String,
        to new: String
    ) -> [(old: String, new: String)] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        let (removed, inserted) = changedOffsets(from: oldLines, to: newLines)
        var pairs: [(old: String, new: String)] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldLines.count || newIndex < newLines.count {
            let oldStart = oldIndex
            let newStart = newIndex
            while removed.contains(oldIndex) || inserted.contains(newIndex) {
                oldIndex += removed.contains(oldIndex) ? 1 : 0
                newIndex += inserted.contains(newIndex) ? 1 : 0
            }
            let oldBlock = Array(oldLines[oldStart ..< oldIndex])
            let newBlock = Array(newLines[newStart ..< newIndex])
            if oldBlock.count == newBlock.count {
                pairs += zip(oldBlock, newBlock).map { (old: $0.0, new: $0.1) }
            } else if !oldBlock.isEmpty, !newBlock.isEmpty {
                let whole = (
                    old: oldBlock.joined(separator: "\n"),
                    new: newBlock.joined(separator: "\n")
                )
                pairs.append(whole)
            }
            oldIndex += 1
            newIndex += 1
        }
        return pairs
    }

    private static func isRewritten(_ old: [String], _ new: [String]) -> Bool {
        guard old.count + new.count <= maxComparedUnits else {
            return true
        }
        var counts: [String: Int] = [:]
        old.forEach { counts[$0, default: 0] -= 1 }
        new.forEach { counts[$0, default: 0] += 1 }
        return counts.values.reduce(0) { $0 + abs($1) } > maxChangedUnits
    }

    private static func paragraphHunks(
        from oldUnits: [String],
        to newUnits: [String]
    ) -> [EditHunk] {
        guard !isRewritten(oldUnits, newUnits) else {
            return []
        }
        let (removed, inserted) = changedOffsets(from: oldUnits, to: newUnits)
        var hunks: [EditHunk] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldUnits.count || newIndex < newUnits.count {
            guard removed.contains(oldIndex) || inserted.contains(newIndex) else {
                oldIndex += 1
                newIndex += 1
                continue
            }
            let oldStart = oldIndex
            let newStart = newIndex
            // 刪和加可能交錯出現，兩邊都走到沒改動的字才算這一處結束。
            while removed.contains(oldIndex) || inserted.contains(newIndex) {
                while removed.contains(oldIndex) {
                    oldIndex += 1
                }
                while inserted.contains(newIndex) {
                    newIndex += 1
                }
            }
            let leadingStart = max(newStart - contextLength, 0)
            let trailingEnd = min(newIndex + contextLength, newUnits.count)
            let hunk = EditHunk(
                before: oldUnits[oldStart ..< oldIndex].joined(),
                after: newUnits[newStart ..< newIndex].joined(),
                leading: newUnits[leadingStart ..< newStart].joined(),
                trailing: newUnits[newIndex ..< trailingEnd].joined()
            )
            if isMeaningful(hunk) {
                hunks.append(hunk)
            }
        }
        return hunks
    }

    /// 連著的英文字母與數字算一格，其他一個字一格。
    static func units(of text: String) -> [String] {
        var units: [String] = []
        var isInWord = false
        for character in text {
            let isWordPart = character.isASCII && (character.isLetter || character.isNumber)
            if isWordPart, isInWord {
                units[units.count - 1].append(character)
            } else {
                units.append(String(character))
            }
            isInWord = isWordPart
        }
        return units
    }

    /// 改前被刪掉的在第幾格、改後新加的在第幾格。
    private static func changedOffsets(
        from old: [String],
        to new: [String]
    ) -> (removed: Set<Int>, inserted: Set<Int>) {
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in new.difference(from: old) {
            switch change {
            case let .remove(offset, _, _):
                removed.insert(offset)
            case let .insert(offset, _, _):
                inserted.insert(offset)
            }
        }
        return (removed, inserted)
    }

    /// 只動了標點、空白、換行的不算：那是排版，不是用詞。
    /// 2026-11-26 例外：把拆開的英文詞拼回來（Open AI 改成 OpenAI）算改用詞。
    static func isMeaningful(_ hunk: EditHunk) -> Bool {
        stripped(hunk.before) != stripped(hunk.after) || joinsEnglishWord(hunk)
    }

    /// 改前有「英文字母、空白、英文字母」，改後同樣的字只是沒了那個空白。
    /// 中英之間、英文跟數字之間（iPhone 15）拿掉空白還是排版，不算。
    private static func joinsEnglishWord(_ hunk: EditHunk) -> Bool {
        guard hasSplitEnglishWord(hunk.before), !hasSplitEnglishWord(hunk.after) else {
            return false
        }
        return hunk.before.filter { !$0.isWhitespace } == hunk.after.filter { !$0.isWhitespace }
    }

    private static func hasSplitEnglishWord(_ text: String) -> Bool {
        let characters = Array(text)
        let inner = characters.indices.dropFirst().dropLast()
        return inner.contains { isSplit(at: $0, in: characters) }
    }

    private static func isSplit(at index: Int, in characters: [Character]) -> Bool {
        guard characters[index].isWhitespace else {
            return false
        }
        return isEnglishLetter(characters[index - 1]) && isEnglishLetter(characters[index + 1])
    }

    private static func isEnglishLetter(_ character: Character) -> Bool {
        character.isASCII && character.isLetter
    }

    private static func stripped(_ text: String) -> String {
        let ignored = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        let kept = text.unicodeScalars.filter { !ignored.contains($0) }
        return String(String.UnicodeScalarView(kept))
    }
}
