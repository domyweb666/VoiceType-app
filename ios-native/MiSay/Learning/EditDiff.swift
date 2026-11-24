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

    static func hunks(from old: String, to new: String) -> [EditHunk] {
        let oldUnits = units(of: old)
        let newUnits = units(of: new)
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
    static func isMeaningful(_ hunk: EditHunk) -> Bool {
        stripped(hunk.before) != stripped(hunk.after)
    }

    private static func stripped(_ text: String) -> String {
        let ignored = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        let kept = text.unicodeScalars.filter { !ignored.contains($0) }
        return String(String.UnicodeScalarView(kept))
    }
}
