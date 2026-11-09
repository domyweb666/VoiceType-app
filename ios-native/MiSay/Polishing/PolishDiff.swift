import Foundation

/// W3「AI 改了什麼」（2026-11-09，原第三批）：口語稿跟 AI 剛整理出來的文字稿逐字比，
/// 整篇切成一段一段：沒動、刪掉、加上。給人確認 AI 沒改掉原意，只在手機上算，不送任何地方。
/// 跟 `EditDiff` 分開：那支只抓幾處送去學習，這支要把整篇照順序排出來給人看。
struct PolishDiff: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case same
        case removed
        case added
    }

    struct Run: Equatable, Sendable {
        let kind: Kind
        let text: String
    }

    /// 兩邊加起來超過這麼多字就不比：比對的時間與記憶體跟長度相乘，兩小時以上的稿子手機會卡。
    static let maxCompareCharacters = 60000

    let runs: [Run]
    /// 刪掉、加上了幾個字，空白換行不算。
    let removedCount: Int
    let addedCount: Int

    /// 空白與換行的增減當排版：加上的照沒動顯示（文字稿的分段才看得出來），刪掉的不顯示。
    init(from raw: String, to polished: String) {
        let old = Array(raw)
        let new = Array(polished)
        let (removed, inserted) = Self.changedOffsets(from: old, to: new)
        var builder = Builder()
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < old.count || newIndex < new.count {
            if oldIndex < old.count, removed.contains(oldIndex) {
                builder.remove(old[oldIndex])
                oldIndex += 1
            } else if newIndex < new.count, inserted.contains(newIndex) {
                builder.add(new[newIndex])
                newIndex += 1
            } else if oldIndex < old.count, newIndex < new.count {
                builder.keep(new[newIndex])
                oldIndex += 1
                newIndex += 1
            } else {
                // 比對結果跟兩邊長度對不上：不該發生，停在這裡，不越界。
                break
            }
        }
        runs = builder.finished()
        removedCount = builder.removedCount
        addedCount = builder.addedCount
    }

    static func isTooLong(raw: String, polished: String) -> Bool {
        raw.count + polished.count > maxCompareCharacters
    }

    /// 口語稿被刪掉的字在第幾個、文字稿新加的字在第幾個。
    private static func changedOffsets(
        from old: [Character],
        to new: [Character]
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

    /// 一個字一個字收，同一種的接成一段。
    private struct Builder {
        private(set) var removedCount = 0
        private(set) var addedCount = 0
        private var runs: [Run] = []
        private var currentKind = Kind.same
        private var buffer = ""

        mutating func keep(_ character: Character) {
            append(character, as: .same)
        }

        mutating func remove(_ character: Character) {
            guard !character.isWhitespace else {
                return
            }
            removedCount += 1
            append(character, as: .removed)
        }

        mutating func add(_ character: Character) {
            guard !character.isWhitespace else {
                append(character, as: .same)
                return
            }
            addedCount += 1
            append(character, as: .added)
        }

        mutating func finished() -> [Run] {
            flush()
            return runs
        }

        private mutating func append(_ character: Character, as kind: Kind) {
            if kind != currentKind {
                flush()
                currentKind = kind
            }
            buffer.append(character)
        }

        private mutating func flush() {
            if !buffer.isEmpty {
                runs.append(Run(kind: currentKind, text: buffer))
                buffer = ""
            }
        }
    }
}
