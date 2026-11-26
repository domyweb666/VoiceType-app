import Foundation

/// 性能檢查 H1 第 2 步（2026-11-26）：長稿的逐字比對分段做。
/// 系統的 `difference(from:)` 記憶體照改動量的平方長，一小時的稿整篇丟進去會吃到 1 GB 以上。
/// 兩邊加起來在 `maxDirectUnits` 以內照舊整篇比，結果跟以前一模一樣。
/// 超過就先找兩邊都只出現一次的一小串字當錨點，照順序對起來，只在錨點之間的空隙逐字比；
/// 記憶體只跟最大的那段空隙有關，不跟整篇長度有關。
/// 不用段落或句號切：口語稿常常整篇沒有換行，潤飾又會改標點，照句子切兩邊對不起來。
/// `PolishDiff` 比字、`MeaningAlignment` 比數字，兩支共用這一支。
enum ChunkedDifference {
    /// 兩邊加起來在這以內就整篇比（2026-11-26 第 1 步定的上限），短稿的結果不變。
    static let maxDirectUnits = 20000
    /// 錨點幾個字一串：太短容易碰巧一樣，太長在改得多的稿裡找不到。
    static let anchorLength = 6
    /// 錨點之間的空隙兩邊加起來在這以內才逐字比，最多吃約 36 MB。
    /// 比這長就在空隙裡再找錨點；找不到就整段當刪掉、加上（多半是整段重寫）。
    static let maxGapUnits = 3000
    /// 空隙裡再找錨點最多找幾層，免得一直切下去。
    static let maxDepth = 4

    /// 一組對上的錨點：口語稿從第幾個開始、文字稿從第幾個開始，各 `anchorLength` 個一樣。
    private struct Anchor {
        let old: Int
        let new: Int
    }

    /// 舊的那份被刪掉的在第幾個、新的那份新加的在第幾個。
    static func changedOffsets<Element: Hashable>(
        from old: [Element],
        to new: [Element]
    ) -> (removed: Set<Int>, inserted: Set<Int>) {
        var removed = Set<Int>()
        var inserted = Set<Int>()
        if old.count + new.count <= maxDirectUnits {
            compareDirectly(old[...], new[...], removed: &removed, inserted: &inserted)
        } else {
            collect(old[...], new[...], depth: 0, removed: &removed, inserted: &inserted)
        }
        return (removed, inserted)
    }

    /// 切片的位置就是整篇的位置，收進來的都是整篇的第幾個。
    private static func collect<Element: Hashable>(
        _ old: ArraySlice<Element>,
        _ new: ArraySlice<Element>,
        depth: Int,
        removed: inout Set<Int>,
        inserted: inout Set<Int>
    ) {
        guard old.count + new.count > maxGapUnits else {
            compareDirectly(old, new, removed: &removed, inserted: &inserted)
            return
        }
        let found = depth < maxDepth ? anchors(old, new) : []
        guard !found.isEmpty else {
            removed.formUnion(old.indices)
            inserted.formUnion(new.indices)
            return
        }
        var oldStart = old.startIndex
        var newStart = new.startIndex
        for anchor in found {
            let oldGap = old[oldStart ..< anchor.old]
            let newGap = new[newStart ..< anchor.new]
            collect(oldGap, newGap, depth: depth + 1, removed: &removed, inserted: &inserted)
            oldStart = anchor.old + anchorLength
            newStart = anchor.new + anchorLength
        }
        let oldTail = old[oldStart...]
        let newTail = new[newStart...]
        collect(oldTail, newTail, depth: depth + 1, removed: &removed, inserted: &inserted)
    }

    /// 原本的比法：系統的 `difference(from:)`。
    private static func compareDirectly<Element: Hashable>(
        _ old: ArraySlice<Element>,
        _ new: ArraySlice<Element>,
        removed: inout Set<Int>,
        inserted: inout Set<Int>
    ) {
        guard !old.isEmpty || !new.isEmpty else {
            return
        }
        // 換成從 0 起算的陣列再比，比出來的第幾個再加回切片的起點。
        for change in Array(new).difference(from: Array(old)) {
            switch change {
            case let .remove(offset, _, _):
                removed.insert(old.startIndex + offset)
            case let .insert(offset, _, _):
                inserted.insert(new.startIndex + offset)
            }
        }
    }

    /// 兩邊都只出現一次的那幾串字，挑出前後順序對得起來、彼此不重疊的。
    private static func anchors<Element: Hashable>(
        _ old: ArraySlice<Element>,
        _ new: ArraySlice<Element>
    ) -> [Anchor] {
        let oldStarts = uniqueStarts(in: old)
        let newStarts = uniqueStarts(in: new)
        var pairs = oldStarts.compactMap { key, oldStart in
            newStarts[key].map { Anchor(old: oldStart, new: $0) }
        }
        pairs.sort { $0.old < $1.old }
        return nonOverlapping(longestIncreasing(pairs))
    }

    /// 每串字從第幾個開始；出現不只一次的拿掉，碰巧一樣的不當錨點。
    private static func uniqueStarts<Element: Hashable>(
        in slice: ArraySlice<Element>
    ) -> [ArraySlice<Element>: Int] {
        guard slice.count >= anchorLength else {
            return [:]
        }
        var starts: [ArraySlice<Element>: Int] = [:]
        var repeated = Set<ArraySlice<Element>>()
        for start in slice.startIndex ... slice.endIndex - anchorLength {
            let key = slice[start ..< start + anchorLength]
            if starts.updateValue(start, forKey: key) != nil {
                repeated.insert(key)
            }
        }
        for key in repeated {
            starts.removeValue(forKey: key)
        }
        return starts
    }

    /// 已照口語稿排好；挑文字稿那邊也一路往後的最多那幾個（最長遞增子序列）。
    /// 搬過位置的句子對不進來，就留在空隙裡逐字比。
    private static func longestIncreasing(_ pairs: [Anchor]) -> [Anchor] {
        // tails[k]：長度 k + 1 的序列，結尾最小的是 pairs 的第幾個。
        var tails: [Int] = []
        var previous = [Int](repeating: -1, count: pairs.count)
        for (index, pair) in pairs.enumerated() {
            var low = 0
            var high = tails.count
            while low < high {
                let middle = (low + high) / 2
                if pairs[tails[middle]].new < pair.new {
                    low = middle + 1
                } else {
                    high = middle
                }
            }
            if low > 0 {
                previous[index] = tails[low - 1]
            }
            if low == tails.count {
                tails.append(index)
            } else {
                tails[low] = index
            }
        }
        var picked: [Anchor] = []
        var cursor = tails.last ?? -1
        while cursor >= 0 {
            picked.append(pairs[cursor])
            cursor = previous[cursor]
        }
        return picked.reversed()
    }

    /// 錨點彼此重疊（同一句裡連著好幾串都對上）只留前面那個，後面的字由空隙去比。
    private static func nonOverlapping(_ anchors: [Anchor]) -> [Anchor] {
        var kept: [Anchor] = []
        var nextOld = Int.min
        var nextNew = Int.min
        for anchor in anchors where anchor.old >= nextOld && anchor.new >= nextNew {
            kept.append(anchor)
            nextOld = anchor.old + anchorLength
            nextNew = anchor.new + anchorLength
        }
        return kept
    }
}
