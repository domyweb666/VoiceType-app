import Foundation

/// 方塊 M5 的一篇：口語稿一定有（轉錄完就落地），文字稿潤飾成功才有。
/// 欄位對應 PRD「一篇的資料結構（口語稿、文字稿、時間、長度、用的模型）」。
/// Hashable 給 D6「打開這篇」用 `navigationDestination(item:)` 推頁。
struct Transcript: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let durationSeconds: Double
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
        updatedAt = Date()
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
