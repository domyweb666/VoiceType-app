import Foundation

/// 方塊 M4：長口語稿切成一塊一塊送潤飾（S2-3）。一小時約 1.5 萬字整篇送要 72～86 秒、常常超時；
/// 每塊約 2,000 字只要 10 秒左右，失敗也只重做那一塊。切在句尾，不把一句話拆到兩塊。
enum PolishChunks {
    static let maxCharacters = 2000
    /// 句尾離塊頭太近（不到一半）就不切在那裡，免得切出一小塊；整塊都沒有句尾時硬切。
    static let minCutRatio = 0.5
    static let sentenceEnds: Set<Character> = ["。", "！", "？", "!", "?", "…", "\n"]

    static func split(_ text: String, maxCharacters: Int = maxCharacters) -> [String] {
        var chunks: [String] = []
        var rest = Substring(text)
        let minCutOffset = Int(Double(maxCharacters) * minCutRatio)
        while rest.count > maxCharacters {
            let window = rest.prefix(maxCharacters)
            var cut = window.endIndex
            if let end = window.lastIndex(where: { sentenceEnds.contains($0) }),
               window.distance(from: window.startIndex, to: end) >= minCutOffset
            {
                cut = window.index(after: end)
            }
            chunks.append(String(rest[..<cut]))
            rest = rest[cut...]
        }
        if !rest.isEmpty || chunks.isEmpty {
            chunks.append(String(rest))
        }
        return chunks
    }

    /// 塊與塊接起來時多一個換段：每塊各自潤飾，結尾的段落不會剛好接得上。
    static func join(_ drafts: [String]) -> String {
        drafts.joined(separator: "\n\n")
    }
}
