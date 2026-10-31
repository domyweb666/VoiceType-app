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
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        durationSeconds: Double,
        rawText: String,
        draftText: String? = nil,
        polishModel: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.rawText = rawText
        self.draftText = draftText
        self.polishModel = polishModel
        self.updatedAt = updatedAt
    }

    /// 畫面與複製用的那份：有文字稿用文字稿，沒有就先用口語稿。
    var displayText: String {
        draftText ?? rawText
    }
}
