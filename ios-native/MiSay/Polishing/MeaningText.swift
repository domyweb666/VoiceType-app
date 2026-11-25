import Foundation

/// 片 J2：口語稿或文字稿拆成一個字一格，比對用。口語稿常是簡體、文字稿是繁體，兩邊都轉成簡體小寫再比；
/// 一個字對一個字，所以位置跟原文一樣。標點空白不比（整理過的標點幾乎都不同），另外記位置。
struct MeaningText: Sendable {
    let originals: [Character]
    /// 每個字轉成簡體小寫，跟 `originals` 一樣長。
    let folded: [Character]
    /// 標點空白以外的字在 `originals` 的第幾個。
    let positions: [Int]
    /// 標點空白以外的字，跟 `positions` 一樣長。
    let words: [Character]
    /// 第幾個字前面有幾個標點空白以外的字。
    let ranks: [Int]

    init(_ text: String) {
        let allFolded = Self.fold(text)
        var wordPositions: [Int] = []
        var wordRanks: [Int] = []
        for (offset, character) in allFolded.enumerated() {
            wordRanks.append(wordPositions.count)
            if character.isLetter || character.isNumber {
                wordPositions.append(offset)
            }
        }
        originals = Array(text)
        folded = allFolded
        positions = wordPositions
        words = wordPositions.map { allFolded[$0] }
        ranks = wordRanks
    }

    /// 常數表（不算否定的詞、成語）也用同一種轉法，才不會兩邊轉得不一樣。
    static func fold(_ text: String) -> [Character] {
        var cache: [Character: Character] = [:]
        var result: [Character] = []
        for character in text {
            let foldedCharacter = cache[character] ?? foldOne(character)
            cache[character] = foldedCharacter
            result.append(foldedCharacter)
        }
        return result
    }

    /// 系統的轉換一個字一個字叫很慢，上面記著，同一個字只轉一次。
    /// 轉完不是剛好一個字就留原字，位置才對得上。
    private static func foldOne(_ character: Character) -> Character {
        let original = String(character)
        let simplified = original.applyingTransform(StringTransform("Hant-Hans"), reverse: false)
        let lowered = (simplified ?? original).lowercased()
        guard lowered.count == 1, let first = lowered.first else {
            return character
        }
        return first
    }
}
