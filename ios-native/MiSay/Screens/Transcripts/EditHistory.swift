import Foundation

/// 2026-11-15 米：要在手機上寫長文。誤刪一段只能搖手機太危險，所以自己記復原、重做。
/// 不靠系統的復原：按格式鈕、換上 AI 改的那段都是整份字換掉，系統那份紀錄會斷。
/// 連著打的字算一步（停超過 `coalesceSeconds` 才算下一步）；一次差很多字（貼上、換上一段）自己一步。
/// 2026-11-17（參考 MarkText）：每一步只記「哪裡、拿掉什麼、放進什麼」，不再記整份字。
/// 5000 字的稿子記 100 步，原本是 100 份全文，現在只有改到的那幾個字。
struct EditHistory: Equatable {
    static let limit = 100
    static let coalesceSeconds: Double = 1.5
    static let bigChangeCharacters = 20

    /// 一步：在第幾格（UTF-16）把 `removed` 換成 `inserted`。反過來做就是復原。
    struct Change: Equatable {
        let location: Int
        let removed: String
        let inserted: String

        var inverse: Change {
            Change(location: location, removed: inserted, inserted: removed)
        }

        /// 套到 `text` 上；那個位置的字對不上（不該發生）就是 nil，寧可不動也不要改壞。
        func applied(to text: String) -> String? {
            let source = text as NSString
            let length = (removed as NSString).length
            guard location >= 0, location + length <= source.length,
                  source.substring(with: NSRange(location: location, length: length)) == removed
            else {
                return nil
            }
            return source.replacingCharacters(
                in: NSRange(location: location, length: length),
                with: inserted
            )
        }

        /// 兩份字前後一樣的部分去掉，剩下中間不一樣的那段。不切在半個 emoji 上。
        static func between(_ old: String, _ new: String) -> Change {
            let oldUnits = Array(old.utf16)
            let newUnits = Array(new.utf16)
            let shorter = min(oldUnits.count, newUnits.count)
            var prefix = 0
            while prefix < shorter, oldUnits[prefix] == newUnits[prefix] {
                prefix += 1
            }
            if prefix > 0, UTF16.isLeadSurrogate(oldUnits[prefix - 1]) {
                prefix -= 1
            }
            var suffix = 0
            let oldLast = oldUnits.count - 1
            let newLast = newUnits.count - 1
            while suffix < shorter - prefix,
                  oldUnits[oldLast - suffix] == newUnits[newLast - suffix] {
                suffix += 1
            }
            if suffix > 0, UTF16.isTrailSurrogate(oldUnits[oldUnits.count - suffix]) {
                suffix -= 1
            }
            let old = old as NSString
            let new = new as NSString
            return Change(
                location: prefix,
                removed: old.substring(with: NSRange(
                    location: prefix,
                    length: oldUnits.count - prefix - suffix
                )),
                inserted: new.substring(with: NSRange(
                    location: prefix,
                    length: newUnits.count - prefix - suffix
                ))
            )
        }
    }

    /// 每一步把「改之後」變回「改之前」。
    private(set) var undoStack: [Change] = []
    private(set) var redoStack: [Change] = []
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
        guard old != new else {
            return
        }
        let isBurst = lastChangeAt.map { now.timeIntervalSince($0) < Self.coalesceSeconds } ?? false
        let isBigChange = abs(new.count - old.count) > Self.bigChangeCharacters
        lastChangeAt = now
        redoStack = []
        // 連著打：把這幾個字併進上一步。先用上一步退回這一步開始前的字，再跟現在比一次。
        if isBurst, !isBigChange, let last = undoStack.last,
           let stepStart = last.applied(to: old) {
            undoStack[undoStack.count - 1] = Change.between(new, stepStart)
            return
        }
        undoStack.append(Change.between(new, old))
        if undoStack.count > Self.limit {
            undoStack.removeFirst()
        }
    }

    /// 回上一步的字；沒有上一步、或對不上就是 nil。
    mutating func undo(current: String) -> String? {
        guard let step = undoStack.popLast() else {
            return nil
        }
        guard let previous = step.applied(to: current) else {
            // 對不上代表紀錄跟畫面已經分家，留著只會越錯越多，整個清掉。
            undoStack = []
            redoStack = []
            return nil
        }
        redoStack.append(step.inverse)
        return apply(previous)
    }

    mutating func redo(current: String) -> String? {
        guard let step = redoStack.popLast() else {
            return nil
        }
        guard let next = step.applied(to: current) else {
            redoStack = []
            return nil
        }
        undoStack.append(step.inverse)
        return apply(next)
    }

    private mutating func apply(_ text: String) -> String {
        applied = text
        lastChangeAt = nil
        return text
    }

    /// 復原之後游標放哪：新的那份字裡，跟原本不一樣的那一段的後面（第幾個字）。
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
