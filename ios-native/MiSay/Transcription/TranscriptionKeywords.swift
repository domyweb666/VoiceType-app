import Foundation

/// 片 J1：自訂詞彙改走 gpt-transcribe 的 `keywords[]`，不再跟上一段結尾搶提示詞那 200 字。
/// 官方文件：詞裡有 `<`、`>`、換行，整個請求會被拒，所以那種詞不送。
enum TranscriptionKeywords {
    /// 2026-11-25 實測 950 個收、1,000 個回 400；300 個各 50 字也收。官方沒寫上限，留很寬的餘裕。
    static let maxCount = 300
    /// 再長就不是一個詞了。
    static let maxCharacters = 50
    /// 同一天實測：只給 zh-tw 多半回簡體，zh-tw 加 en 多半回繁體。米的口述也夾英文。
    static let languages = ["zh-tw", "en"]

    private static let refusedCharacters: Set<Character> = ["<", ">"]

    /// 新加的詞排在最後面，超過上限時留新的。
    static func usable(from vocabulary: [String]) -> [String] {
        let words = vocabulary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(isAccepted)
        return Array(words.suffix(maxCount))
    }

    private static func isAccepted(_ word: String) -> Bool {
        guard !word.isEmpty, word.count <= maxCharacters else {
            return false
        }
        let isRefused = word.contains { $0.isNewline || refusedCharacters.contains($0) }
        let hasControl = word.unicodeScalars
            .contains { CharacterSet.controlCharacters.contains($0) }
        return !isRefused && !hasControl
    }
}
