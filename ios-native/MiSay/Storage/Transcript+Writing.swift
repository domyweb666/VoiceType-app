import Foundation

/// 2026-11-15 米：光用手機就要能在編輯區打出五千字以上的長文。所以要能從空白開始寫，不用先錄音。
extension Transcript {
    /// 新文稿：沒有錄音、沒有口語稿，文字稿是空的（不是 nil，所以直接進編輯框）。
    static func blankDraft(at date: Date = Date()) -> Transcript {
        Transcript(createdAt: date, durationSeconds: 0, rawText: "", draftText: "", updatedAt: date)
    }

    /// 自己打的，不是錄音轉的：沒有口語稿、沒有長度。接著錄過之後就不算了。
    /// 改寫來的也沒有錄音，但字是 AI 寫的，不算。
    var isWritten: Bool {
        !isDerived && rawText.isEmpty && durationSeconds == 0
    }

    /// 開了新文稿、一個字都還沒寫。
    var isBlankDraft: Bool {
        let text = (draftText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return isWritten && text.isEmpty && (rewrites ?? []).isEmpty
    }
}
