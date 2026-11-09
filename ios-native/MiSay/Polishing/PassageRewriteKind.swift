import Foundation

/// W4 改一段（2026-11-09）：文字稿裡選一段，叫 AI 縮短、講清楚、改口語、改書面。
/// 改好先給人看，按「換上」才換；提示詞寫死在這裡，不給改（11/08 決定照舊）。
enum PassageRewriteKind: String, CaseIterable, Identifiable {
    case shorten
    case expand
    case spoken
    case written

    /// 一次最多改這麼多字：選太長就該用「改寫成其他格式」整篇改。
    static let maxPassageCharacters = 3000
    /// 前後文各帶幾個字給模型看。
    static let contextCharacters = 600

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .shorten: "縮短"
        case .expand: "講清楚一點"
        case .spoken: "改口語"
        case .written: "改書面"
        }
    }

    var systemImage: String {
        switch self {
        case .shorten: "arrow.down.right.and.arrow.up.left"
        case .expand: "arrow.up.left.and.arrow.down.right"
        case .spoken: "bubble.left"
        case .written: "doc.text"
        }
    }

    var prompt: String {
        Self.intro + "\n\n" + instructions + "\n\n" + RewriteKind.sharedRules + "\n" + Self
            .outputRule
    }

    /// 選的那段與前後文都只放在 user 那一則（安全標準五）。
    static func userContent(_ passage: PassageContext) -> String {
        "<before>\n\(passage.before)\n</before>\n<passage>\n\(passage.text)\n</passage>\n"
            + "<after>\n\(passage.after)\n</after>"
    }

    private static let intro = """
    你是幫內容創作者改稿的編輯。user 那則裡，<passage> 是他在自己的文字稿裡選起來要改的那一段；\
    <before>、<after> 是前後文，只是讓你看懂在講什麼，不要改、不要輸出。
    """

    private static let outputRule = "- 只輸出改好的那一段。不要輸出前後文，不要加引號、標籤或說明。"

    private var instructions: String {
        switch self {
        case .shorten:
            "把這段縮短到大約一半：留下論點和例子，刪重複的話和繞圈的句子。用他原本的詞，不要換成更文的說法。"
        case .expand:
            "把這段講清楚一點：補上原本跳過的推理步驟，把「這個」「那個」換成前後文裡指的東西。"
                + "只能用這段和前後文裡有的內容，不准加新的事實、數字、例子。長度最多變成一倍半。"
        case .spoken:
            "把這段改得更像講話：句子短一點、用平常講話的詞，可以直接對讀者說「你」。意思不變。"
        case .written:
            "把這段改得更像寫的：口頭禪、重複、倒裝整理掉，句子接順。不要改成公文腔或論文腔，"
                + "還是要像他自己寫的。意思不變。"
        }
    }
}
