import Foundation
import NaturalLanguage

/// 2026-11-25 米：改字時自動認出被改對的詞就好（參考豆鍵的自動學詞：在手機上認、不問 AI、刪過的不再學）。
/// 一處修改讀起來像原本的，就是聽錯被改對；再看改的那幾個字屬於哪個詞，收那個詞。
/// 整段只在手機上算，不送任何地方、不花錢。
enum CorrectedWords {
    /// 中文 2 到 6 個字（跟豆鍵一樣），有英文的放寬到 12。
    static let hanLengths = 2 ... 6
    static let mixedLengths = 2 ... 12

    /// 改成這些字不收，也不拿來跟旁邊的字併成詞：虛字、代名詞、常接在名字前面的動詞。
    private static let functionCharacters = Set<Character>(
        "的得地底了啦著在再是有又和跟與就也都很要會去來到把被讓給不沒這那哪個一"
            + "嗎嘛吧呢啊喔我你妳您他她它牠祂們做作對從用說想還找叫問看買吃喝賣帶請約等見寫聽"
    )

    /// 台灣最常見的三十個姓：三個字的人名斷詞多半拆成單字，只有左邊是這些字才連姓一起收。
    private static let commonSurnames = Set<Character>(
        "陳林黃張李王吳劉蔡楊許鄭謝郭洪曾邱廖賴周徐蘇葉莊呂江何蕭羅高"
    )

    static func find(from old: String, to new: String) -> [String] {
        var words: [String] = []
        for hunk in EditDiff.hunks(from: old, to: new) {
            if let word = word(in: hunk), !words.contains(word) {
                words.append(word)
            }
        }
        return words
    }

    static func word(in hunk: EditHunk) -> String? {
        let heard = trimmed(hunk.before)
        let written = trimmed(hunk.after)
        let spelling = 1 ... mixedLengths.upperBound
        // 太長的是整句重寫，不算改一個詞；空的是單純加字或刪字。
        guard spelling.contains(heard.count), spelling.contains(written.count),
              SoundAlike.matches(heard, written)
        else {
            return nil
        }
        guard SoundAlike.isAllHan(written) else {
            return mixedWord(written, heard: heard)
        }
        if written.allSatisfy(functionCharacters.contains) {
            return nil
        }
        let text = Array(hunk.leading + hunk.after + hunk.trailing)
        let skipped = hunk.after.prefix { !$0.isLetter && !$0.isNumber }.count
        let start = hunk.leading.count + skipped
        return hanWord(covering: start ..< start + written.count, in: text)
    }

    /// 英文或中英夾雜：要有字母，中間不能隔著標點或換行。
    /// 英文改英文要有大寫才收：make 改成 made 是改文法，專有名詞才會有大寫。
    private static func mixedWord(_ written: String, heard: String) -> String? {
        let isEnglishEdit = (heard + written).allSatisfy(\.isASCII)
        guard !isEnglishEdit || written.contains(where: \.isUppercase) else {
            return nil
        }
        let isOneWord = written.allSatisfy { $0.isLetter || $0.isNumber || " -.&+'".contains($0) }
        let hasLetter = written.contains { $0.isLetter }
        return isOneWord && hasLetter && mixedLengths.contains(written.count) ? written : nil
    }

    /// 改的那幾個字屬於哪個詞：照系統斷詞撐開。只剩一個字（斷詞不認得的店名、人名）就跟旁邊單獨一個字的併起來。
    private static func hanWord(covering changed: Range<Int>, in text: [Character]) -> String? {
        let tokens = tokenRanges(in: text)
        var span = changed
        for token in tokens where token.overlaps(changed) {
            let start = min(span.lowerBound, token.lowerBound)
            span = start ..< max(span.upperBound, token.upperBound)
        }
        if span.count == 1 {
            span = joinedWithNeighbor(span, tokens: tokens, text: text)
        }
        span = withSurname(span, tokens: tokens, text: text)
        let candidates = [span, changed].map { String(text[$0]) }
        return candidates.first { SoundAlike.isAllHan($0) && hanLengths.contains($0.count) }
    }

    /// 先看左邊再看右邊：名字與店名多半聽錯後面的字。
    private static func joinedWithNeighbor(
        _ span: Range<Int>,
        tokens: [Range<Int>],
        text: [Character]
    ) -> Range<Int> {
        let left = tokens.first { $0.upperBound == span.lowerBound }
        let right = tokens.first { $0.lowerBound == span.upperBound }
        for neighbor in [left, right].compactMap({ $0 }) where neighbor.count == 1 {
            let character = text[neighbor.lowerBound]
            if SoundAlike.isHan(character), !functionCharacters.contains(character) {
                let start = min(neighbor.lowerBound, span.lowerBound)
                return start ..< start + 2
            }
        }
        return span
    }

    /// 2026-11-26：陳炳彰斷成陳、炳、彰三個單字，上面只併到「炳彰」。
    /// 兩個字都是斷詞不認得的單字、左邊緊貼的也是單字而且是常見的姓，就把姓併進來。
    /// 斷詞認得的詞不往外撐：「這張蘋果」收「蘋果」，不收「張蘋果」。
    private static func withSurname(
        _ span: Range<Int>,
        tokens: [Range<Int>],
        text: [Character]
    ) -> Range<Int> {
        let isUnknownWord = tokens.filter { $0.overlaps(span) }.allSatisfy { $0.count == 1 }
        guard span.count == 2, isUnknownWord,
              let left = tokens.first(where: { $0.upperBound == span.lowerBound }),
              left.count == 1, commonSurnames.contains(text[left.lowerBound])
        else {
            return span
        }
        return left.lowerBound ..< span.upperBound
    }

    private static func tokenRanges(in characters: [Character]) -> [Range<Int>] {
        let text = String(characters)
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.traditionalChinese)
        return tokenizer.tokens(for: text.startIndex ..< text.endIndex).map { range in
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            return start ..< start + text.distance(from: range.lowerBound, to: range.upperBound)
        }
    }

    private static func trimmed(_ text: String) -> String {
        let ignored = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        return text.trimmingCharacters(in: ignored)
    }
}
