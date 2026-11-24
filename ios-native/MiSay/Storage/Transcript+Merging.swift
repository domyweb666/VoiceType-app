import Foundation

/// 接著錄併進來的一段錄音：留存檔名是那一段的 id，從併入那時起再留 7 天（`RetainedRecordings`）。
struct MergedRecording: Codable, Hashable {
    let id: UUID
    let mergedAt: Date
}

/// 2026-11-24：同一篇被兩邊改到時怎麼合，都是純判斷。
extension Transcript {
    /// 接著錄接回來之前叫：獨立那一篇會刪掉，它的錄音和漏字提示改記在這篇上。
    /// 口語稿一律接在最後面，所以段號接在這篇後面數。
    mutating func adoptRecording(of added: Transcript, now: Date = Date()) {
        let own = MergedRecording(id: added.id, mergedAt: now)
        mergedRecordings = (mergedRecordings ?? []) + (added.mergedRecordings ?? []) + [own]
        let offset = segmentCount
        let missing = (added.possiblyMissingSegments ?? []).map { $0 + offset }
        if !missing.isEmpty {
            possiblyMissingSegments = (possiblyMissingSegments ?? []) + missing
        }
    }

    /// 時間對照表一段一列；接著錄過的沒有，照長度估。
    private var segmentCount: Int {
        let estimate = durationSeconds / Double(WAVSegmenter.targetSegmentSeconds)
        return timeline?.count ?? Int(estimate.rounded(.up))
    }

    /// 流水手上是開始整理時的那份，存之前把人在這段時間改的換成存檔裡最新的。
    /// 存檔裡的文字稿要被換掉，先留一版。
    mutating func keepUserFields(from stored: Transcript) {
        var kept = stored
        if stored.draftText != draftText {
            kept.keepVersion()
        }
        title = stored.title
        tags = stored.tags
        goalCharacters = stored.goalCharacters
        publishedAt = stored.publishedAt
        rewrites = stored.rewrites
        mergedRecordings = stored.mergedRecordings
        trashedAt = stored.trashedAt
        versions = kept.versions
    }

    /// 同一篇有兩份（匯入過舊備份、刪兩次）：正文用最後改的那份，另一份的字留成一版。
    func combined(with other: Transcript, now: Date = Date()) -> Transcript {
        let isOtherNewer = other.updatedAt > updatedAt
        var newer = isOtherNewer ? other : self
        let older = isOtherNewer ? self : other
        let known = Set((newer.versions ?? []).map(\.id))
        var kept = (newer.versions ?? []) + (older.versions ?? []).filter { !known.contains($0.id) }
        kept.sort { $0.savedAt < $1.savedAt }
        let text = older.displayText
        if !Self.isBlank(text), text != newer.displayText {
            kept.append(DraftVersion(savedAt: now, text: text))
        }
        newer.versions = kept.isEmpty ? nil : Self.prunedVersions(kept)
        let ownRecordings = newer.mergedRecordings ?? []
        let missing = (older.mergedRecordings ?? []).filter { !ownRecordings.contains($0) }
        let recordings = ownRecordings + missing
        newer.mergedRecordings = recordings.isEmpty ? nil : recordings
        return newer
    }
}
