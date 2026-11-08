import Foundation

/// 一處修改：改前、改後，加上改後那份前後各一小段字，讓模型看得懂是在改什麼。
struct EditHunk: Equatable {
    let before: String
    let after: String
    let leading: String
    let trailing: String
}

/// 2026-11-08：拿「上次學到哪」的文字稿跟現在的比，找出人改過的地方（自動詞彙、從修改學習用）。
/// 用系統內建的比對（`difference(from:)`），長文也快；只在手機上算，不送任何地方。
enum EditDiff {
    /// 前後文各帶幾個字。
    static let contextLength = 12
    /// 改前或改後超過這麼長就截斷：整段重寫照樣看得出習慣，不用整段送。
    static let maxSpanLength = 80
    /// 一篇最多送幾處。
    static let maxHunks = 20

    static func hunks(from old: String, to new: String) -> [EditHunk] {
        let oldCharacters = Array(old)
        let newCharacters = Array(new)
        let changes = newCharacters.difference(from: oldCharacters)
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in changes {
            switch change {
            case let .remove(offset, _, _):
                removed.insert(offset)
            case let .insert(offset, _, _):
                inserted.insert(offset)
            }
        }

        var hunks: [EditHunk] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldCharacters.count || newIndex < newCharacters.count {
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
            let trailingEnd = min(newIndex + contextLength, newCharacters.count)
            let hunk = EditHunk(
                before: clipped(oldCharacters[oldStart ..< oldIndex]),
                after: clipped(newCharacters[newStart ..< newIndex]),
                leading: String(newCharacters[leadingStart ..< newStart]),
                trailing: String(newCharacters[newIndex ..< trailingEnd])
            )
            if isMeaningful(hunk) {
                hunks.append(hunk)
            }
            if hunks.count == maxHunks {
                break
            }
        }
        return hunks
    }

    /// 只動了標點、空白、換行的不算：那是排版，不是用詞或習慣。
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

    private static func clipped(_ characters: ArraySlice<Character>) -> String {
        guard characters.count > maxSpanLength else {
            return String(characters)
        }
        return String(characters.prefix(maxSpanLength)) + "…"
    }
}
