import Foundation

/// 2026-11-25：改前、改後讀起來像不像。像的才是聽錯被改對，不像的是換說法。
/// 中文換成拼音（系統內建的轉寫，不連網），英文照字母。
enum SoundAlike {
    /// 有英文的：字母至少這麼像，或子音至少這麼像（子音太少的不看，短字容易碰巧一樣）。
    private static let minLetterSimilarity = 0.6
    private static let minConsonantSimilarity = 0.65
    private static let minConsonants = 3
    /// 全中文的：每三個字容許一個字不像（整個名字重打，其中一個字讀音差一點）。
    private static let syllablesPerMiss = 3

    static func matches(_ heard: String, _ written: String) -> Bool {
        if isAllHan(heard), isAllHan(written) {
            return hanMatches(heard, written)
        }
        let heardLetters = letters(of: heard)
        let writtenLetters = letters(of: written)
        guard !heardLetters.isEmpty, !writtenLetters.isEmpty else {
            return false
        }
        if similarity(heardLetters, writtenLetters) >= minLetterSimilarity {
            return true
        }
        let heardConsonants = heardLetters.filter(isConsonant)
        let writtenConsonants = writtenLetters.filter(isConsonant)
        guard min(heardConsonants.count, writtenConsonants.count) >= minConsonants else {
            return false
        }
        return similarity(heardConsonants, writtenConsonants) >= minConsonantSimilarity
    }

    static func isAllHan(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy(isHan)
    }

    static func isHan(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(\.properties.isIdeographic)
    }

    private static func hanMatches(_ heard: String, _ written: String) -> Bool {
        guard heard.count == written.count else {
            return false
        }
        let pairs = zip(heard, written)
        let misses = pairs.filter { looseSyllable($0.0) != looseSyllable($0.1) }.count
        return misses * syllablesPerMiss <= written.count
    }

    /// 不帶聲調的拼音，再把台灣口音常混的併成同一個：ㄓㄔㄕ與ㄗㄘㄙ、ㄋㄌㄖ、ㄣ與ㄥ。
    private static func looseSyllable(_ character: Character) -> String {
        var syllable = pinyin(of: character)
        let initials = [("zh", "z"), ("ch", "c"), ("sh", "s"), ("n", "l"), ("r", "l")]
        if let initial = initials.first(where: { syllable.hasPrefix($0.0) }) {
            syllable = initial.1 + syllable.dropFirst(initial.0.count)
        }
        if syllable.hasSuffix("ing") || syllable.hasSuffix("eng") {
            syllable.removeLast()
        }
        return syllable
    }

    private static func pinyin(of character: Character) -> String {
        let latin = String(character).applyingTransform(.mandarinToLatin, reverse: false)
        let plain = latin?.applyingTransform(.stripDiacritics, reverse: false)
        return (plain ?? String(character)).lowercased()
    }

    /// 中文換拼音、英文小寫，其他丟掉；c 當 k（Claude 跟克勞德）。
    private static func letters(of text: String) -> [Character] {
        text.flatMap { character -> [Character] in
            let spelled = isHan(character) ? pinyin(of: character) : character.lowercased()
            let plain = spelled.filter { $0.isASCII && $0.isLetter }
            return plain.map { $0 == "c" ? "k" : $0 }
        }
    }

    private static func isConsonant(_ letter: Character) -> Bool {
        !"aeiouwy".contains(letter)
    }

    /// 1 是一模一樣，0 是完全不像：一減掉「要改幾個字母」佔的比例。
    private static func similarity(_ first: [Character], _ second: [Character]) -> Double {
        let longest = max(first.count, second.count)
        guard longest > 0 else {
            return 0
        }
        var previous = Array(0 ... second.count)
        for (row, letter) in first.enumerated() {
            var current = [row + 1]
            for (column, other) in second.enumerated() {
                let replaced = previous[column] + (letter == other ? 0 : 1)
                current.append(min(replaced, previous[column + 1] + 1, current[column] + 1))
            }
            previous = current
        }
        return 1 - Double(previous[second.count]) / Double(longest)
    }
}
