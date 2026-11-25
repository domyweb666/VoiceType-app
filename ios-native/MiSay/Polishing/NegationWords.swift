import Foundation

/// 片 J2：哪些「不、沒、別、未、無」真的是否定。
enum NegationWords {
    /// 帶著這個字的詞；`offset` 是這個字在詞裡的第幾個。
    private struct Entry {
        let characters: [Character]
        let offset: Int
    }

    private static let negations = Set(MeaningText.fold("不沒別未無"))
    /// 同一處換成這些字，意思還是否定（不容易 → 很難）。
    private static let equivalents = negations.union(MeaningText.fold("非勿莫否難缺"))
    private static let notYet = MeaningText.fold("沒")
    private static let finished = MeaningText.fold("了")
    private static let having = MeaningText.fold("有")

    /// 這個字在這些詞裡從來不是否定，少了也不會反過來。
    private static let neverNegating = table([
        "未來", "特別", "分別", "個別", "類別", "性別", "區別", "級別", "告別", "識別", "差別", "辨別",
        "鑑別", "派別", "國別", "離別", "別人", "別的", "別墅", "別處", "別名",
    ])

    /// 整個詞換掉沒關係（不過 → 但）；詞的其他字還在、只少了這個字就反過來了（沒關係 → 有關係）。
    private static let harmlessWhenWhole = table([
        "不過", "不只", "不止", "不但", "不僅", "不管", "不論", "不然", "不錯", "不斷", "不禁", "不妨",
        "不愧", "不時", "不停", "不知不覺", "不用說", "不好意思", "不外乎", "差不多", "對不起", "了不起",
        "說不定", "要不", "三不五", "沒錯", "沒關係", "未婚", "無論", "無聊", "無常", "無數", "無限",
        "無意", "無奈", "無所謂", "無比", "無線", "無形", "無非",
    ])

    /// 兩個不互相抵掉，一起不見才沒關係（不得不 → 得）。
    private static let doubleNegatives = table(["不得不"])

    /// 可能真的在否定的字在第幾個。
    static func indexes(in text: MeaningText) -> Set<Int> {
        Set(text.words.indices.filter { index in
            negations.contains(text.words[index]) && canNegate(at: index, in: text)
        })
    }

    /// 意思還是否定的字在第幾個（看文字稿有沒有換一種說法用）。
    /// `includesHarmless`：不過、無論這種也算，口語稿少掉的是這種詞時才用（無論 → 不論）。
    static func equivalentIndexes(in text: MeaningText, includesHarmless: Bool) -> Set<Int> {
        let real = indexes(in: text).filter { index in
            includesHarmless || indexesToVanish(at: index, in: text.words).isEmpty
        }
        let others = text.words.indices.filter { index in
            equivalents.contains(text.words[index]) && !negations.contains(text.words[index])
        }
        return real.union(others)
    }

    /// 這個字在「整個詞換掉沒關係」的詞裡時，回哪幾個字要一起不見才不算改意思；不在就是空的。
    static func indexesToVanish(at index: Int, in words: [Character]) -> Set<Int> {
        var result = Set<Int>()
        for range in ranges(of: harmlessWhenWhole, at: index, in: words) {
            result.formUnion(range)
        }
        for range in ranges(of: doubleNegatives, at: index, in: words) {
            result.formUnion(range.filter { negations.contains(words[$0]) })
        }
        return result
    }

    private static func canNegate(at index: Int, in text: MeaningText) -> Bool {
        ranges(of: neverNegating, at: index, in: text.words).isEmpty
            && !repeats(1, around: index, in: text.words)
            && !repeats(2, around: index, in: text.words)
            && !isClosingQuestion(at: index, in: text)
    }

    /// A 不 A（對不對、有沒有、喜歡不喜歡）是在問，不是否定。
    private static func repeats(_ length: Int, around index: Int, in words: [Character]) -> Bool {
        let start = index - length
        let next = index + 1
        guard start >= 0, next + length <= words.count else {
            return false
        }
        return words[start ..< index].elementsEqual(words[next ..< next + length])
    }

    /// 句尾的「了沒」「了沒有」是在問；後面還接著字（到了沒想到）就不是。
    private static func isClosingQuestion(at index: Int, in text: MeaningText) -> Bool {
        let place = text.positions[index]
        guard [text.folded[place]] == notYet, place > 0, [text.folded[place - 1]] == finished
        else {
            return false
        }
        var next = place + 1
        if next < text.folded.count, [text.folded[next]] == having {
            next += 1
        }
        guard next < text.folded.count else {
            return true
        }
        return !text.folded[next].isLetter && !text.folded[next].isNumber
    }

    private static func table(_ list: [String]) -> [Character: [Entry]] {
        var entries: [Character: [Entry]] = [:]
        for word in list {
            let characters = MeaningText.fold(word)
            for (offset, character) in characters.enumerated() where negations.contains(character) {
                entries[character, default: []].append(Entry(
                    characters: characters,
                    offset: offset
                ))
            }
        }
        return entries
    }

    private static func ranges(
        of entries: [Character: [Entry]],
        at index: Int,
        in words: [Character]
    ) -> [Range<Int>] {
        (entries[words[index]] ?? []).compactMap { entry in
            let start = index - entry.offset
            let end = start + entry.characters.count
            guard start >= 0, end <= words.count,
                  words[start ..< end].elementsEqual(entry.characters)
            else {
                return nil
            }
            return start ..< end
        }
    }
}
