import Foundation

/// 2026-11-15 米：要在手機上寫長文。誤刪一段只能搖手機太危險，所以自己記復原、重做。
/// 不靠系統的復原：按格式鈕、換上 AI 改的那段都是整份字換掉，系統那份紀錄會斷。
/// 連著打的字算一步（停超過 `coalesceSeconds` 才算下一步）；一次差很多字（貼上、換上一段）自己一步。
struct EditHistory: Equatable {
    static let limit = 100
    static let coalesceSeconds: Double = 1.5
    static let bigChangeCharacters = 20

    private(set) var undoStack: [String] = []
    private(set) var redoStack: [String] = []
    private var lastChangeAt: Date?
    /// 剛才復原或重做放上去的那份字：編輯框接著會回報「字變了」，那一次不算新的修改。
    private var applied: String?

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// 編輯框的字從 `old` 變成 `new` 時叫。
    mutating func record(from old: String, to new: String, now: Date = .now) {
        if new == applied {
            applied = nil
            return
        }
        applied = nil
        let isBurst = lastChangeAt.map { now.timeIntervalSince($0) < Self.coalesceSeconds } ?? false
        let isBigChange = abs(new.count - old.count) > Self.bigChangeCharacters
        lastChangeAt = now
        redoStack = []
        guard !isBurst || isBigChange else {
            return
        }
        undoStack.append(old)
        if undoStack.count > Self.limit {
            undoStack.removeFirst()
        }
    }

    /// 回上一步的字；沒有上一步是 nil。
    mutating func undo(current: String) -> String? {
        while let previous = undoStack.popLast() {
            if previous != current {
                redoStack.append(current)
                return apply(previous)
            }
        }
        return nil
    }

    mutating func redo(current: String) -> String? {
        while let next = redoStack.popLast() {
            if next != current {
                undoStack.append(current)
                return apply(next)
            }
        }
        return nil
    }

    private mutating func apply(_ text: String) -> String {
        applied = text
        lastChangeAt = nil
        return text
    }

    /// 復原之後游標放哪：新的那份字裡，跟原本不一樣的那一段的後面。
    static func changeEnd(from old: String, to new: String) -> Int {
        let oldCharacters = Array(old)
        let newCharacters = Array(new)
        let shorter = min(oldCharacters.count, newCharacters.count)
        var prefix = 0
        while prefix < shorter, oldCharacters[prefix] == newCharacters[prefix] {
            prefix += 1
        }
        let oldTail = Array(oldCharacters.reversed())
        let newTail = Array(newCharacters.reversed())
        var suffix = 0
        while suffix < shorter - prefix, oldTail[suffix] == newTail[suffix] {
            suffix += 1
        }
        return newCharacters.count - suffix
    }
}
