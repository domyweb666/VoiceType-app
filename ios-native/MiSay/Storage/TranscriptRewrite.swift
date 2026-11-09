import Foundation

/// W1：一篇改寫成別的格式之後存下來的那份（2026-11-09）。跟著那篇存、跟著那篇刪、跟著備份走；
/// 那篇的口語稿和文字稿一個字都不動。
struct TranscriptRewrite: Codable, Hashable, Identifiable {
    let id: UUID
    /// `RewriteKind.rawValue`。存字串不存列舉：哪天拿掉一種，舊的這份照樣讀得出來，不會被當壞檔。
    let kind: String
    let text: String
    let model: String
    let createdAt: Date

    init(id: UUID = UUID(), kind: String, text: String, model: String, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.text = text
        self.model = model
        self.createdAt = createdAt
    }
}
