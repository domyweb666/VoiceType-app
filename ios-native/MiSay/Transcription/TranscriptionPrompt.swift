import Foundation

/// 方塊 M3：轉錄提示詞的組法（舊版照抄）：繁體提示＋專有名詞＋前一段的結尾，全部塞在 200 字內。
/// 前一段結尾是讓切段後的下一段接得上語境；專有名詞是 F2 的自訂詞彙。
enum TranscriptionPrompt {
    static let traditionalHint = "請以臺灣繁體中文（正體字）逐字轉錄，維持口述用語，勿改寫、勿換成簡體字。"
    static let maxCharacters = 200
    private static let vocabularyPrefix = "\n專有名詞："
    private static let previousSeparator = "\n"

    static func build(vocabulary: [String], previousText: String) -> String {
        var head = traditionalHint
        let joined = vocabulary.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "、")
        if !joined.isEmpty {
            let budget = maxCharacters - head.count - vocabularyPrefix.count
            if budget > 0 {
                head += vocabularyPrefix + String(joined.prefix(budget))
            }
        }
        guard head.count < maxCharacters else {
            return String(head.prefix(maxCharacters))
        }
        let tail = previousText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tail.isEmpty else {
            return head
        }
        let budget = maxCharacters - head.count - previousSeparator.count
        guard budget > 0 else {
            return head
        }
        return head + previousSeparator + String(tail.suffix(budget))
    }
}
