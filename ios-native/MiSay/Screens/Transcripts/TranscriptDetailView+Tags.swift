import SwiftUI

/// W6「⋯ → 標籤」：升起 `TagEditorSheet`，按「完成」存回這篇。存法跟改寫一樣先讀存檔裡最新的那份。
extension TranscriptDetailView {
    var tagsSheet: some View {
        TagEditorSheet(
            tags: transcript.tags ?? [],
            knownTags: Self.knownTags(),
            onSave: saveTags
        )
    }

    /// 「標籤…」；有標籤就直接寫出來，不用點進去看。
    static func tagMenuTitle(_ tags: [String]) -> String {
        tags.isEmpty ? "標籤…" : "標籤：" + tags.joined(separator: "、")
    }

    /// 讀不到存檔就只是沒有可以點選的舊標籤，自己打照樣能加。
    private static func knownTags() -> [String] {
        let transcripts = (try? TranscriptStore().loadAll().transcripts) ?? []
        return Transcript.tagsInUse(transcripts)
    }

    private func saveTags(_ tags: [String]) {
        do {
            try updateStored {
                $0.tags = tags.isEmpty ? nil : tags
                $0.updatedAt = Date()
            }
        } catch {
            showNote("標籤沒存進去，再試一次。")
        }
    }
}
