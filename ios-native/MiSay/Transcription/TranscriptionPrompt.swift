import Foundation

/// 方塊 M3：轉錄提示詞的組法：繁體提示＋前一段的結尾，全部塞在 200 字內。
/// 前一段結尾是讓切段後的下一段接得上語境。專有名詞 2026-11-25 起走 `TranscriptionKeywords`。
enum TranscriptionPrompt {
    static let traditionalHint = "請以臺灣繁體中文（正體字）逐字轉錄，維持口述用語，勿改寫、勿換成簡體字。"
    static let maxCharacters = 200
    private static let previousSeparator = "\n"

    static func build(previousText: String) -> String {
        let tail = previousText.trimmingCharacters(in: .whitespacesAndNewlines)
        let budget = maxCharacters - traditionalHint.count - previousSeparator.count
        guard !tail.isEmpty, budget > 0 else {
            return traditionalHint
        }
        return traditionalHint + previousSeparator + traditional(String(tail.suffix(budget)))
    }

    /// 2026-11-25 實測：結尾是簡體，下一段就整段回簡體，一段簡體會一路傳下去。
    /// 只轉送出去的提示，口語稿不動；轉不了就照原字送。
    private static func traditional(_ text: String) -> String {
        text.applyingTransform(StringTransform("Hans-Hant"), reverse: false) ?? text
    }
}
