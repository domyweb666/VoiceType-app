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

    /// 自己打的，現在正文、標題都是空的，底下也沒有改寫稿。可能寫過又全刪了。
    var hasNothingLeft: Bool {
        isWritten && Self.isBlank(draftText ?? "") && Self.isBlank(title ?? "")
            && (rewrites ?? []).isEmpty
    }

    /// 開了新文稿、一個字都還沒寫。取過標題、留過版（寫過又清空）、改寫來的都不算：離開時會直接刪，救不回來。
    var isBlankDraft: Bool {
        hasNothingLeft && (versions ?? []).isEmpty
    }

    /// 只有空白換行也算空的。
    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
