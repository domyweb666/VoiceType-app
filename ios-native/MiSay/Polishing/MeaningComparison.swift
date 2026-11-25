import Foundation

/// 片 J2：口語稿跟文字稿對好之後，找文字稿裡變少的否定字、數字、名字。
/// 回的範圍都是口語稿的第幾個字到第幾個字。
struct MeaningComparison {
    /// 對到的位置前後這麼多字裡還找得到，就不算不見（刪重講、搬到隔壁句）。
    private static let window = 30
    /// 刪重講：否定字連同前兩字或後兩字還在附近。
    private static let contextLength = 2
    /// 後面的字還在時，往前看這麼幾個字有沒有否定字。
    private static let lookBehind = 3
    /// 單獨的「一」幾乎都不是在講數量（一個、一些、一直），只看有沒有被換成別的數字。
    private static let ignoredValue: Double = 1
    private static let minNameLength = 2

    private let old: MeaningText
    private let new: MeaningText
    private let alignment: MeaningAlignment
    private let oldNumbers: [SpokenNumber]
    private let newNumbers: [SpokenNumber]

    init(raw: String, polished: String) {
        old = MeaningText(raw)
        new = MeaningText(polished)
        alignment = MeaningAlignment(from: old.words, to: new.words)
        oldNumbers = SpokenNumber.all(in: old.folded)
        newNumbers = SpokenNumber.all(in: new.folded)
    }

    var originals: [Character] {
        old.originals
    }

    private func originalRange(_ range: Range<Int>) -> Range<Int> {
        old.positions[range.lowerBound] ..< old.positions[range.upperBound - 1] + 1
    }

    /// 文字稿對應位置的前後一段。
    private func nearby(_ oldIndex: Int) -> Range<Int> {
        let anchor = alignment.anchors[oldIndex]
        return max(0, anchor - Self.window) ..< min(new.words.count, anchor + Self.window)
    }

    private func contains(_ word: ArraySlice<Character>, in range: Range<Int>) -> Bool {
        guard word.count <= range.count else {
            return false
        }
        let starts = range.lowerBound ... range.upperBound - word.count
        return starts.contains { start in
            new.words[start ..< start + word.count].elementsEqual(word)
        }
    }
}

/// 否定字。
extension MeaningComparison {
    func lostNegations() -> [Range<Int>] {
        let negations = NegationWords.indexes(in: old)
        let strict = NegationWords.equivalentIndexes(in: new, includesHarmless: false)
        let wide = NegationWords.equivalentIndexes(in: new, includesHarmless: true)
        var lost: [Range<Int>] = []
        for hunk in alignment.hunks {
            // 這一處新加的否定字：換了說法（沒有 → 未），一個抵一個。
            var strictSpare = addedCount(of: strict, in: hunk)
            var wideSpare = addedCount(of: wide, in: hunk)
            for index in hunk.old where negations.contains(index) {
                let vanishing = NegationWords.indexesToVanish(at: index, in: old.words)
                let isInWord = !vanishing.isEmpty
                let isWholeWordGone = isInWord
                    && vanishing.allSatisfy { alignment.matches[$0] == nil }
                guard alignment.matches[index] == nil, !isWholeWordGone,
                      !isCovered(index, equivalents: isInWord ? wide : strict), !isRetold(index)
                else {
                    continue
                }
                if isInWord, wideSpare > 0 {
                    wideSpare -= 1
                } else if strictSpare > 0 {
                    strictSpare -= 1
                } else {
                    lost.append(originalRange(index ..< index + 1))
                }
            }
        }
        return lost
    }

    /// 這一處新加了幾個（不是對到口語稿別的字的）。
    private func addedCount(of indexes: Set<Int>, in hunk: MeaningAlignment.Hunk) -> Int {
        let added = hunk.new.filter { indexes.contains($0) && alignment.sources[$0] == nil }
        return added.count
    }

    /// 後面的字還在、前面就有否定字，而且那個否定字是前一遍講的（中間有刪）或新加的：刪重講。
    /// 隔得跟口語稿一樣遠的是另一個否定字（不急也沒用），不算。
    private func isCovered(_ index: Int, equivalents: Set<Int>) -> Bool {
        let following = index + 1 ..< min(index + 1 + Self.contextLength, old.words.count)
        guard let next = following.first(where: { alignment.matches[$0] != nil }),
              let place = alignment.matches[next]
        else {
            return false
        }
        let candidates = max(0, place - Self.lookBehind) ..< place
        return candidates.contains { candidate in
            guard equivalents.contains(candidate) else {
                return false
            }
            guard let source = alignment.sources[candidate] else {
                return true
            }
            return next - source - 1 > place - candidate
        }
    }

    /// 同一句前後還留著。前後的字都靠在一起、只有這個字不見的是真的被拿掉，不算。
    private func isRetold(_ index: Int) -> Bool {
        guard alignment.keptNeighbors(of: index ..< index + 1) == nil else {
            return false
        }
        let range = nearby(index)
        let end = index + 1 + Self.contextLength
        if end <= old.words.count, contains(old.words[index ..< end], in: range) {
            return true
        }
        let start = index - Self.contextLength
        return start >= 0 && contains(old.words[start ... index], in: range)
    }
}

/// 數字。
extension MeaningComparison {
    func lostNumbers() -> [Range<Int>] {
        oldNumbers.filter { $0.isExact && isLost($0) }.map(\.range)
    }

    private func isLost(_ number: SpokenNumber) -> Bool {
        guard let value = number.values.first else {
            return false
        }
        let words = wordRange(of: number)
        if isReplaced(value, at: words) {
            return true
        }
        guard !Self.isSame(value, Self.ignoredValue) else {
            return false
        }
        return !hasNumber(value, in: nearby(words.lowerBound)) || isRemovedInPlace(value, at: words)
    }

    private func wordRange(of number: SpokenNumber) -> Range<Int> {
        let start = old.ranks[number.range.lowerBound]
        return start ..< old.ranks[number.range.upperBound - 1] + 1
    }

    /// 同一處換成別的數字，那個數字口語稿附近又沒講過：就算別處還有一樣的值也算改掉。
    private func isReplaced(_ value: Double, at words: Range<Int>) -> Bool {
        guard let hunk = alignment.hunks.first(where: { $0.old.overlaps(words) }) else {
            return false
        }
        let candidates = newNumbers.filter { number in
            let rank = new.ranks[number.range.lowerBound]
            return !number.isListMarker && rank >= hunk.new.lowerBound - 1
                && rank < hunk.new.upperBound
        }.flatMap(\.values)
        guard !candidates.contains(where: { Self.isSame($0, value) }) else {
            return false
        }
        return candidates.contains { !wasSpoken($0, near: words.lowerBound) }
    }

    /// 前後的字靠在一起、只有數字不見。
    private func isRemovedInPlace(_ value: Double, at words: Range<Int>) -> Bool {
        guard words.allSatisfy({ alignment.matches[$0] == nil }),
              let neighbors = alignment.keptNeighbors(of: words)
        else {
            return false
        }
        return !hasNumber(value, in: neighbors.before + 1 ..< neighbors.after)
    }

    private func hasNumber(_ value: Double, in range: Range<Int>) -> Bool {
        newNumbers.contains { number in
            range.contains(new.ranks[number.range.lowerBound])
                && number.values.contains { Self.isSame($0, value) }
        }
    }

    private func wasSpoken(_ value: Double, near index: Int) -> Bool {
        oldNumbers.contains { number in
            abs(old.ranks[number.range.lowerBound] - index) <= Self.window
                && number.values.contains { Self.isSame($0, value) }
        }
    }

    /// 一點三億這種乘出來的會差一點點。
    private static func isSame(_ first: Double, _ second: Double) -> Bool {
        let tolerance = 1e-9
        return abs(first - second) <= max(abs(first), abs(second)) * tolerance
    }
}

/// 詞彙表裡的名字。
extension MeaningComparison {
    /// 長的詞先看，Claude Code 標過就不再標裡面的 Claude。
    func lostNames(_ vocabulary: [String]) -> [Range<Int>] {
        let starts = Dictionary(grouping: old.words.indices) { old.words[$0] }
        let names = vocabulary.map { MeaningText($0).words }
            .filter { $0.count >= Self.minNameLength }
            .sorted { $0.count > $1.count }
        var lost: [Range<Int>] = []
        for name in names {
            for start in name.first.flatMap({ starts[$0] }) ?? [] {
                let words = start ..< start + name.count
                guard isWholeName(name, at: words), !isIntact(words),
                      !contains(name[...], in: nearby(start))
                else {
                    continue
                }
                let range = originalRange(words)
                if !lost.contains(where: { $0.overlaps(range) }) {
                    lost.append(range)
                }
            }
        }
        return lost
    }

    /// 英文名字前後不能還接著英文字母（AI 不會對到 said）。
    private func isWholeName(_ name: [Character], at words: Range<Int>) -> Bool {
        guard words.upperBound <= old.words.count, old.words[words].elementsEqual(name) else {
            return false
        }
        let range = originalRange(words)
        let touchesBefore = range.lowerBound > 0
            && Self.isLatin(old.folded[range.lowerBound])
            && Self.isLatin(old.folded[range.lowerBound - 1])
        let touchesAfter = range.upperBound < old.folded.count
            && Self.isLatin(old.folded[range.upperBound - 1])
            && Self.isLatin(old.folded[range.upperBound])
        return !touchesBefore && !touchesAfter
    }

    /// 每個字都對到、而且連在一起：沒動過。
    private func isIntact(_ words: Range<Int>) -> Bool {
        guard let first = alignment.matches[words.lowerBound] else {
            return false
        }
        return words.allSatisfy { alignment.matches[$0] == first + $0 - words.lowerBound }
    }

    private static func isLatin(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber)
    }
}
