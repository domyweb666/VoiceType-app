import SwiftUI

/// 清單看得到哪幾篇、怎麼排、草稿與已發布（2026-11-24 主力編輯器）。
extension TranscriptListView {
    /// 一組：標題與照時間排好的那幾篇。
    struct TranscriptGroup {
        let title: String
        var transcripts: [Transcript]
    }

    enum PublishFilter: String, CaseIterable, Identifiable {
        case draft
        case published

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .draft: "草稿"
            case .published: "已發布"
            }
        }

        var emptyTitle: String {
            switch self {
            case .draft: "沒有草稿"
            case .published: "沒有已發布的文字稿"
            }
        }

        var emptyNote: String {
            switch self {
            case .draft: "每一篇都標成已發布了。"
            case .published: "在清單上把一篇往左滑，就能標成已發布。"
            }
        }

        var emptyImage: String {
            switch self {
            case .draft: "doc.text"
            case .published: "paperplane"
            }
        }

        func includes(_ transcript: Transcript) -> Bool {
            (transcript.publishedAt != nil) == (self == .published)
        }
    }

    /// 最後改的在最上面；同一秒的照錄的時間，順序才不會每次讀都不一樣。
    static func listOrder(_ transcripts: [Transcript]) -> [Transcript] {
        transcripts.sorted {
            ($0.updatedAt, $0.createdAt) > ($1.updatedAt, $1.createdAt)
        }
    }

    /// 搜尋看標題與內容（口語稿與文字稿都算），不分大小寫。
    static func matches(_ transcript: Transcript, keyword: String) -> Bool {
        [transcript.title ?? "", transcript.rawText, transcript.draftText ?? ""]
            .contains { $0.localizedCaseInsensitiveContains(keyword) }
    }

    var visibleTranscripts: [Transcript] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return transcripts.filter { transcript in
            let hasTag = selectedTag.map { (transcript.tags ?? []).contains($0) } ?? true
            let hasStatus = publishFilter?.includes(transcript) ?? true
            let isFound = keyword.isEmpty || Self.matches(transcript, keyword: keyword)
            return transcript.id != pendingDeletion?.id && hasTag && hasStatus && isFound
        }
    }

    /// 照清單順序把每篇塞進它的組，組的順序跟著第一篇出現的順序（最新在上）。
    static func groups(of visible: [Transcript]) -> [TranscriptGroup] {
        var groups: [TranscriptGroup] = []
        for transcript in visible {
            let title = Self.groupTitle(for: transcript.updatedAt)
            if let index = groups.firstIndex(where: { $0.title == title }) {
                groups[index].transcripts.append(transcript)
            } else {
                groups.append(TranscriptGroup(title: title, transcripts: [transcript]))
            }
        }
        return groups
    }

    var pageTitle: String {
        let tagTitle = selectedTag.map { "#" + $0 }
        return tagTitle ?? publishFilter?.title ?? "文字稿"
    }

    var isFiltering: Bool {
        selectedTag != nil || publishFilter != nil
    }

    /// 沒有標籤、也沒有一篇標成已發布，就沒東西可以篩。
    var hasFilters: Bool {
        isFiltering || transcripts.contains { $0.publishedAt != nil }
            || !Transcript.tagsInUse(transcripts).isEmpty
    }

    var publishPicker: some View {
        Picker("照發布狀態看", selection: $publishFilter) {
            Text("草稿和已發布").tag(PublishFilter?.none)
            ForEach(PublishFilter.allCases) { Text($0.title).tag(PublishFilter?.some($0)) }
        }
    }

    /// 還沒整理、正在整理或重轉的不給標：流水手上是舊的一份，做完存回來會把標記蓋掉。
    @ViewBuilder
    func publishButton(_ transcript: Transcript) -> some View {
        if transcript.draftText != nil, !queue.inFlight.contains(transcript.id.uuidString) {
            Button(transcript.publishedAt == nil ? "標成已發布" : "改回草稿") {
                togglePublished(transcript)
            }
        }
    }

    /// 不動 `updatedAt`：字沒改，標一下不該跳到最上面。
    func togglePublished(_ transcript: Transcript) {
        let publishedAt: Date? = transcript.publishedAt == nil ? Date() : nil
        do {
            try TranscriptStore().update(id: transcript.id) { $0.publishedAt = publishedAt }
            reload()
        } catch {
            publishFailed = true
        }
    }
}
