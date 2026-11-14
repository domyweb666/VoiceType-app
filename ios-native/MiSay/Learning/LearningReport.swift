import Foundation

/// 2026-11-15 米：改完字看不出有沒有學。每次學完記一筆，「從修改學習」頁寫出來。
/// 只記數字與時間，不記詞與習慣的內容。
struct LearningReport: Codable, Equatable {
    let date: Date
    /// 這篇送去判斷的修改有幾處；0 表示只動了標點、空白，沒有送。
    let hunkCount: Int
    let addedWords: Int
    let habitCount: Int
    /// 送了但沒成功（沒網路、金鑰有問題、回的不是能讀的格式），下次會再試。
    let failed: Bool

    /// 畫面上那句，不含時間。
    var summary: String {
        if failed {
            return "沒送成功（沒網路，或金鑰有問題）。下次離開文字稿時會再試。"
        }
        guard hunkCount > 0 else {
            return "只改了標點或空白，沒有送出去。"
        }
        return "看了 \(hunkCount) 處修改，加了 \(addedWords) 個詞，習慣現在 \(habitCount) 條。"
    }
}
