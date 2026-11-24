import Foundation

/// 文字稿改之前的樣子（2026-11-15 米：要在手機上寫五千字以上的長文，改壞了要回得去）。
/// 跟文字稿存在同一個檔裡：一樣加密、一樣跟著備份、那篇刪了就一起沒了。
struct DraftVersion: Codable, Hashable, Identifiable {
    let id: UUID
    let savedAt: Date
    let text: String

    init(id: UUID = UUID(), savedAt: Date = Date(), text: String) {
        self.id = id
        self.savedAt = savedAt
        self.text = text
    }
}

extension Transcript {
    /// 最近幾版全部留：每版是整篇的字，留太多檔案會肥，清單讀起來變慢。
    static let maxVersions = 8
    /// 更早的每天只留最後一版，最多留幾天（2026-11-24）。只留 8 版的話，認真改一天就把上星期的擠光。
    static let maxDailyVersions = 14
    /// 同一次打開連著改，隔這麼久才再留一版。
    static let versionIntervalSeconds: Double = 600

    /// 把現在存著的文字稿留一版，舊的在前；超過的照 `prunedVersions` 丟。
    /// 空的、跟上一版一樣、跟 AI 剛整理好的那份一樣（那份本來就留著）都不留。
    mutating func keepVersion(now: Date = Date()) {
        guard let text = draftText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text != versions?.last?.text,
              text != originalDraft
        else {
            return
        }
        let kept = (versions ?? []) + [DraftVersion(savedAt: now, text: text)]
        versions = Self.prunedVersions(kept)
    }

    /// 最近 8 版照留；更早的一天留最後一版。那天已經有版在最近 8 版裡就不另外留。
    static func prunedVersions(
        _ versions: [DraftVersion],
        calendar: Calendar = .current
    ) -> [DraftVersion] {
        let recent = Array(versions.suffix(maxVersions))
        var coveredDays = Set(recent.map { calendar.startOfDay(for: $0.savedAt) })
        var daily: [DraftVersion] = []
        for version in versions.dropLast(maxVersions).reversed() {
            guard daily.count < maxDailyVersions else {
                break
            }
            if coveredDays.insert(calendar.startOfDay(for: version.savedAt)).inserted {
                daily.append(version)
            }
        }
        return Array(daily.reversed()) + recent
    }
}
