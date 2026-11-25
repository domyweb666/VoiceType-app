import Foundation

/// 片 J2：稿子裡的一個數字。三百二十跟 320、百分之十五跟 15% 讀成同一個值。
struct SpokenNumber: Equatable {
    /// 在原文的第幾個字到第幾個字。
    let range: Range<Int>
    /// 讀得出來就一個值；「兩三天」這種約數讀不出來，拆成裡面的每個數字。
    let values: [Double]
    let isExact: Bool
    /// 行首的「1.」「2、」是條列的編號，不是講出來的數字。
    let isListMarker: Bool

    /// 這些詞裡的數字不是在講數量。
    private static let idioms = [
        "三不五時", "亂七八糟", "五花八門", "三番兩次", "一清二楚", "丟三落四", "四處", "四周", "十分",
        "十足", "萬一", "千萬", "再三", "三心兩意", "五顏六色", "四面八方", "七七八八",
    ].map { MeaningText.fold($0) }
    private static let percentPrefix = MeaningText.fold("百分之")
    private static let tenPoints = MeaningText.fold("十分")
    private static let realAfterTenPoints = Set(MeaningText.fold("鐘之"))
    private static let clockEndings = Set(MeaningText.fold("分刻"))
    private static let hundred = MeaningText.fold("百")
    private static let wholePercent: Double = 100
    private static let listMarkerEndings: Set<Character> = [".", "、", ")"]
    private static let thousandsGroup = 3

    /// 整份稿子的數字，照順序。`folded` 是 `MeaningText` 轉過的字。
    static func all(in folded: [Character]) -> [SpokenNumber] {
        let skipped = skippedPositions(in: folded)
        var numbers: [SpokenNumber] = []
        var index = 0
        while index < folded.count {
            guard !skipped.contains(index), NumberReading.isNumeric(folded[index]) else {
                index += 1
                continue
            }
            var end = index + 1
            while let next = nextEnd(after: end, in: folded, skipped: skipped) {
                end = next
            }
            numbers.append(number(in: folded, range: index ..< end))
            index = end
        }
        return numbers
    }

    private static func number(in folded: [Character], range: Range<Int>) -> SpokenNumber {
        let run = Array(folded[range])
        let value = isWholePercent(run, in: folded, start: range.lowerBound)
            ? wholePercent
            : NumberReading.value(of: run)
        return SpokenNumber(
            range: range,
            values: value.map { [$0] } ?? NumberReading.looseValues(of: run),
            isExact: value != nil,
            isListMarker: isListMarker(run, in: folded, range: range)
        )
    }

    /// 百分之百的最後那個「百」。
    private static func isWholePercent(
        _ run: [Character],
        in folded: [Character],
        start: Int
    ) -> Bool {
        guard run == hundred, start >= percentPrefix.count else {
            return false
        }
        return folded[start - percentPrefix.count ..< start].elementsEqual(percentPrefix)
    }

    private static func isListMarker(
        _ run: [Character],
        in folded: [Character],
        range: Range<Int>
    ) -> Bool {
        guard run.allSatisfy({ NumberReading.isDigit($0) }), range.upperBound < folded.count,
              listMarkerEndings.contains(folded[range.upperBound])
        else {
            return false
        }
        guard let before = folded[..<range.lowerBound].last(where: { $0 != " " }) else {
            return true
        }
        return before.isNewline
    }

    /// 數字唸到這裡，後面還接得下去就回接到哪裡：小數點、千分位、單位前後的空白（3,000 萬）。
    private static func nextEnd(
        after end: Int,
        in folded: [Character],
        skipped: Set<Int>
    ) -> Int? {
        guard end < folded.count, !skipped.contains(end) else {
            return nil
        }
        if NumberReading.isNumeric(folded[end]) {
            return end + 1
        }
        let next = end + 1
        guard next < folded.count, !skipped.contains(next),
              NumberReading.isNumeric(folded[next]), joins(at: end, in: folded)
        else {
            return nil
        }
        return next + 1
    }

    private static func joins(at index: Int, in folded: [Character]) -> Bool {
        if NumberReading.isSpokenPoint(folded[index]) {
            return isDecimalPoint(at: index, in: folded)
        }
        let before = folded[index - 1]
        let after = folded[index + 1]
        let areDigits = NumberReading.isDigit(before) && NumberReading.isDigit(after)
        switch folded[index] {
        case ".":
            return areDigits
        case ",":
            let group = folded[(index + 1)...].prefix(thousandsGroup)
            return areDigits && group.count == thousandsGroup
                && group.allSatisfy { NumberReading.isDigit($0) }
        case " ":
            let unitFirst = NumberReading.isUnit(before) && NumberReading.isDigit(after)
            return unitFirst || (NumberReading.isDigit(before) && NumberReading.isUnit(after))
        default:
            return false
        }
    }

    /// 三點五是 3.5；三點五分、三點五十是時間。
    private static func isDecimalPoint(at index: Int, in folded: [Character]) -> Bool {
        guard NumberReading.isSpokenDigit(folded[index - 1]),
              NumberReading.isSpokenDigit(folded[index + 1])
        else {
            return false
        }
        let followingIndex = index + 2
        guard followingIndex < folded.count else {
            return true
        }
        let following = folded[followingIndex]
        return !NumberReading.isUnit(following) && !clockEndings.contains(following)
    }

    /// 成語裡的數字，還有「百分之」的百。
    private static func skippedPositions(in folded: [Character]) -> Set<Int> {
        var skipped = Set<Int>()
        for start in folded.indices {
            if starts(with: percentPrefix, at: start, in: folded) {
                skipped.insert(start)
            }
            for idiom in idioms where isIdiom(idiom, at: start, in: folded) {
                skipped.formUnion(start ..< start + idiom.count)
            }
        }
        return skipped
    }

    private static func isIdiom(
        _ idiom: [Character],
        at start: Int,
        in folded: [Character]
    ) -> Bool {
        guard starts(with: idiom, at: start, in: folded) else {
            return false
        }
        // 三千萬、五十分：前面還有數字，是在講數量。
        let followsNumber = start > 0 && NumberReading.isNumeric(folded[start - 1])
        if followsNumber, NumberReading.isNumeric(folded[start]) {
            return false
        }
        let end = start + idiom.count
        let isMinutes = idiom == tenPoints && end < folded.count
            && realAfterTenPoints.contains(folded[end])
        return !isMinutes
    }

    private static func starts(
        with word: [Character],
        at start: Int,
        in folded: [Character]
    ) -> Bool {
        let end = start + word.count
        guard end <= folded.count, folded[start] == word.first else {
            return false
        }
        return folded[start ..< end].elementsEqual(word)
    }
}
