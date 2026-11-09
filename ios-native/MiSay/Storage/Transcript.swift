import Foundation

/// 方塊 M5 的一篇：口語稿一定有（轉錄完就落地），文字稿潤飾成功才有。
/// 欄位對應 PRD「一篇的資料結構（口語稿、文字稿、時間、長度、用的模型）」。
/// Hashable 給 D6「打開這篇」用 `navigationDestination(item:)` 推頁。
struct Transcript: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    /// K3 接著錄之後會加長，所以是 var。
    var durationSeconds: Double
    /// 口語稿：語音直接轉出來的那份（詞彙表）。
    var rawText: String
    /// 文字稿：潤飾後的那份；還沒潤飾或潤飾失敗時是 nil。
    var draftText: String?
    /// 潤飾用的模型名稱（F4 要讓歷史看得出來）。
    var polishModel: String?
    /// 潤飾方式的 `PolishStyle.rawValue`（2026-11-08 加）。存字串不存列舉：哪天認不得的值，
    /// 這篇照樣讀得出來，不會被當成壞檔搬走。舊的篇沒有這欄，是 nil。
    var polishStyle: String?
    /// 潤飾剛出來、還沒被人改過的那份文字稿（2026-11-08 加）。之後自動詞彙、從修改學習要拿它跟
    /// `draftText` 比，看人改了哪裡。改字只動 `draftText`，這欄不動；舊的篇沒有這欄，是 nil。
    var originalDraft: String?
    /// 上次學到哪（2026-11-08 加）：學過的那份文字稿。下次只比它跟現在的，同一處修改不會學兩次。
    var learnedDraft: String?
    /// 轉錄回來字數少得不像那段講的話量、重送一次還是少的段（從 1 數，S2-2）。沒有就是 nil。
    var possiblyMissingSegments: [Int]?
    /// 長稿潤飾做到一半時已經好的那幾塊（S2-3）。全部好了接成 `draftText`，這欄清成 nil。
    var polishedChunks: [String]?
    /// 文字稿存好的時間（S2-5）：留存錄音從這時起再留 7 天。舊的篇沒有這欄，用 `updatedAt`。
    var polishedAt: Date?
    /// 最後一次接著錄的時間（K3）：有值就是好幾段錄音接起來的，留存錄音只對得上第一段，
    /// 不給「從錄音重新轉錄」、不給播原音。（用時間不用可選的布林：規矩不准。）
    var combinedAt: Date?
    /// 錄音中標的重點，第幾秒（K6）。沒標過是 nil。
    var marks: [Double]?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        durationSeconds: Double,
        rawText: String,
        draftText: String? = nil,
        polishModel: String? = nil,
        polishStyle: String? = nil,
        originalDraft: String? = nil,
        learnedDraft: String? = nil,
        possiblyMissingSegments: [Int]? = nil,
        polishedChunks: [String]? = nil,
        polishedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.rawText = rawText
        self.draftText = draftText
        self.polishModel = polishModel
        self.polishStyle = polishStyle
        self.originalDraft = originalDraft
        self.learnedDraft = learnedDraft
        self.possiblyMissingSegments = possiblyMissingSegments
        self.polishedChunks = polishedChunks
        self.polishedAt = polishedAt
        self.updatedAt = updatedAt
    }

    /// 畫面與複製用的那份：有文字稿用文字稿，沒有就先用口語稿。
    var displayText: String {
        draftText ?? rawText
    }

    /// 潤飾成功：文字稿與原稿一起換成這份，記下模型與潤飾方式。
    mutating func applyPolish(_ draft: String, model: String, style: PolishStyle) {
        draftText = draft
        originalDraft = draft
        learnedDraft = draft
        polishModel = model
        polishStyle = style.rawValue
        polishedChunks = nil
        polishedAt = Date()
        updatedAt = Date()
    }

    /// 從錄音重新轉錄（S2-5）：換成新的口語稿，文字稿與跟它有關的欄位全部清掉，等重新潤飾。
    mutating func replaceRawText(_ text: String, possiblyMissing: [Int]?) {
        rawText = text
        possiblyMissingSegments = possiblyMissing
        draftText = nil
        originalDraft = nil
        learnedDraft = nil
        polishedChunks = nil
        polishModel = nil
        polishStyle = nil
        polishedAt = nil
        updatedAt = Date()
    }

    /// K3 接著錄：另一篇接在這篇後面，中間空一行。這篇原本的字一個都不動。
    /// 原稿與學過的那份也一起接，之後比對「改了哪裡」才不會把接上去的那段當成修改。
    mutating func append(_ other: Transcript) {
        let ownDraft = draftText ?? rawText
        let ownOriginal = originalDraft ?? ownDraft
        let ownLearned = learnedDraft ?? ownOriginal
        let otherDraft = other.draftText ?? other.rawText
        let otherOriginal = other.originalDraft ?? otherDraft
        rawText = Self.joined(rawText, other.rawText)
        draftText = Self.joined(ownDraft, otherDraft)
        originalDraft = Self.joined(ownOriginal, otherOriginal)
        learnedDraft = Self.joined(ownLearned, other.learnedDraft ?? otherOriginal)
        // 接上去那段的重點，秒數接在這篇後面算。
        let shifted = (other.marks ?? []).map { $0 + durationSeconds }
        if !shifted.isEmpty {
            marks = (marks ?? []) + shifted
        }
        durationSeconds += other.durationSeconds
        combinedAt = Date()
        updatedAt = Date()
    }

    private static func joined(_ first: String, _ second: String) -> String {
        first + "\n\n" + second
    }

    /// 有沒有還沒學過的修改：從上次學到的（沒學過就是原稿）到現在的文字稿有變。
    /// 舊的篇沒有原稿，比不出改了哪裡，不算。
    var unlearnedEdit: (from: String, to: String)? {
        guard let draftText, let baseline = learnedDraft ?? originalDraft,
              baseline != draftText
        else {
            return nil
        }
        return (baseline, draftText)
    }
}
