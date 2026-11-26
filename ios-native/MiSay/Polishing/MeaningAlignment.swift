import Foundation

/// 片 J2：口語稿的每個字對到文字稿的第幾個字（標點空白不算在內）。
struct MeaningAlignment {
    /// 一處修改：口語稿的哪幾個字換成文字稿的哪幾個字。
    struct Hunk {
        let old: Range<Int>
        let new: Range<Int>
    }

    /// 隔著這麼幾個沒動的字還算同一處：換句話說時，中間常碰巧有一兩個字一樣。
    private static let maxSameBetween = 2
    /// 前後的字都留著、在文字稿裡最多隔這麼遠，才算「只有中間不見或換掉」。
    private static let maxKeptDistance = 3

    /// 口語稿第幾個字 → 文字稿第幾個字；被刪的是 nil。
    let matches: [Int?]
    /// 文字稿第幾個字 → 口語稿第幾個字；新加的沒有。
    let sources: [Int: Int]
    /// 口語稿第幾個字大約落在文字稿的哪裡，被刪的也有。
    let anchors: [Int]
    let hunks: [Hunk]

    init(from old: [Character], to new: [Character]) {
        let aligned = Self.align(from: old, to: new)
        var newToOld: [Int: Int] = [:]
        var places: [Int] = []
        var nextNew = 0
        for (oldIndex, match) in aligned.enumerated() {
            places.append(match ?? nextNew)
            if let match {
                newToOld[match] = oldIndex
                nextNew = match + 1
            }
        }
        matches = aligned
        sources = newToOld
        anchors = places
        hunks = Self.makeHunks(matches: aligned, newCount: new.count)
    }

    /// 這幾個字前後的字都還在、而且在文字稿裡靠在一起：回前後兩個字在文字稿的位置。
    func keptNeighbors(of range: Range<Int>) -> (before: Int, after: Int)? {
        guard range.lowerBound > 0, range.upperBound < matches.count,
              let before = matches[range.lowerBound - 1], let after = matches[range.upperBound],
              after - before <= Self.maxKeptDistance
        else {
            return nil
        }
        return (before, after)
    }

    /// 跟 `PolishDiff` 同一種比法（兩萬字以上分段比，`ChunkedDifference`）。字先換成數字再比，長文快很多。
    private static func align(from old: [Character], to new: [Character]) -> [Int?] {
        let (removed, inserted) = ChunkedDifference.changedOffsets(
            from: codes(of: old),
            to: codes(of: new)
        )
        var aligned: [Int?] = []
        var newIndex = 0
        for oldIndex in old.indices {
            if removed.contains(oldIndex) {
                aligned.append(nil)
                continue
            }
            while inserted.contains(newIndex) {
                newIndex += 1
            }
            // 比對結果跟長度對不上：不該發生，當成被刪，不越界。
            aligned.append(newIndex < new.count ? newIndex : nil)
            newIndex += 1
        }
        return aligned
    }

    private static func codes(of characters: [Character]) -> [UInt32] {
        characters.map { $0.unicodeScalars.first?.value ?? 0 }
    }

    private static func makeHunks(matches: [Int?], newCount: Int) -> [Hunk] {
        var hunks: [Hunk] = []
        var oldStart = 0
        var newStart = 0
        for (oldIndex, match) in matches.enumerated() {
            guard let match else {
                continue
            }
            append(Hunk(old: oldStart ..< oldIndex, new: newStart ..< match), to: &hunks)
            oldStart = oldIndex + 1
            newStart = match + 1
        }
        append(Hunk(old: oldStart ..< matches.count, new: newStart ..< newCount), to: &hunks)
        return hunks
    }

    private static func append(_ hunk: Hunk, to hunks: inout [Hunk]) {
        guard !hunk.old.isEmpty || !hunk.new.isEmpty else {
            return
        }
        guard let last = hunks.last,
              hunk.old.lowerBound - last.old.upperBound <= maxSameBetween
        else {
            hunks.append(hunk)
            return
        }
        hunks[hunks.count - 1] = Hunk(
            old: last.old.lowerBound ..< hunk.old.upperBound,
            new: last.new.lowerBound ..< hunk.new.upperBound
        )
    }
}
