import Foundation

/// 垃圾桶（2026-11-24 主力編輯器）：刪掉的篇先放 Transcripts/Trash/，一樣加密，30 天後才真的刪。
/// 搬的順序一律是「那邊寫成功，才刪這邊」；中途被殺會兩邊都有，以沒在垃圾桶的那份為準，
/// 所以這裡不會拿垃圾桶的蓋掉清單裡的。留存錄音由叫的人刪（`RetainedRecordings`）。
extension TranscriptStore {
    static let trashKeepDays = 30
    static let secondsPerDay: TimeInterval = 24 * 60 * 60
    private static let trashDirectoryName = "Transcripts/Trash"

    func trashDirectoryURL() throws -> URL {
        try ensuredDirectory(named: Self.trashDirectoryName)
    }

    /// 搬進垃圾桶的是存檔裡最新的那份。已經不在清單就不用搬。
    /// 垃圾桶已經有同一篇就合成一份，不直接蓋；那份解不開就先另存。
    func moveToTrash(id: UUID, now: Date = Date()) throws {
        guard var transcript = try load(id: id) else {
            return
        }
        let url = try trashURL(for: id)
        do {
            if let trashed = try read(url) {
                transcript = transcript.combined(with: trashed, now: now)
            }
        } catch Failure.unreadable {
            try setAside(url)
        }
        transcript.trashedAt = now
        try write(transcript, to: url)
        try delete(id: id)
    }

    func loadFromTrash(id: UUID) throws -> Transcript? {
        try read(trashURL(for: id))
    }

    /// 整理到一半被丟進垃圾桶的篇，整理好存在垃圾桶那份：放回來還有。
    func saveInTrash(_ transcript: Transcript) throws {
        try write(transcript, to: trashURL(for: transcript.id))
    }

    /// 放回清單。清單裡已經有同一篇（例如匯入過備份）就不放，免得蓋掉它。
    func restoreFromTrash(id: UUID) throws {
        guard try !isInList(id) else {
            throw Failure.cannotWrite
        }
        let url = try trashURL(for: id)
        guard var transcript = try read(url) else {
            throw Failure.notFound
        }
        transcript.trashedAt = nil
        try save(transcript)
        try remove(url)
    }

    /// 真的刪掉垃圾桶裡的一篇。回 true 表示這篇從此哪裡都沒有了，錄音可以跟著刪。
    func deleteFromTrash(id: UUID) throws -> Bool {
        try remove(trashURL(for: id))
        return try !isInList(id)
    }

    /// 垃圾桶裡看得到的篇，剛丟的在前。清單裡也有的不算；解不開的另存到 Unreadable/，不刪。
    func loadTrash() throws -> [Transcript] {
        let visible = try readTrash().filter { try !isInList($0.id) }
        return visible.sorted {
            ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast)
        }
    }

    /// 放超過 30 天的真的刪掉，回從此哪裡都沒有了的那幾篇。沒有記丟進來時間的不自動刪。
    func deleteExpiredTrash(now: Date = Date()) throws -> [UUID] {
        let expired = try readTrash().filter { Self.isExpired(trashedAt: $0.trashedAt, now: now) }
        return try expired.map(\.id).filter { try deleteFromTrash(id: $0) }
    }

    /// 只看檔名，不解密：解不開的那幾篇也要算在內，它們的錄音才不會被當孤兒刪掉。
    func trashedIDs() throws -> Set<UUID> {
        let ids = try trashFiles().compactMap {
            UUID(uuidString: $0.deletingPathExtension().lastPathComponent)
        }
        return Set(ids)
    }

    static func isExpired(trashedAt: Date?, now: Date) -> Bool {
        guard let trashedAt else {
            return false
        }
        return now.timeIntervalSince(trashedAt) >= Double(trashKeepDays) * secondsPerDay
    }

    /// 還有幾天會真的刪；不到一天算 1 天，已經到期（還沒清）是 0。
    static func daysLeft(trashedAt: Date, now: Date) -> Int {
        let elapsedDays = now.timeIntervalSince(trashedAt) / secondsPerDay
        let left = Int((Double(trashKeepDays) - elapsedDays).rounded(.up))
        return min(max(left, 0), trashKeepDays)
    }

    private func readTrash() throws -> [Transcript] {
        let files = try trashFiles()
        guard !files.isEmpty else {
            return []
        }
        let key = try loadKey()
        var transcripts: [Transcript] = []
        for file in files {
            if let transcript = Self.decrypt(file, using: key) {
                transcripts.append(transcript)
            } else {
                // 搬不動就留在原地：檔還在，下次再搬。
                try? setAside(file)
            }
        }
        return transcripts
    }

    private func trashFiles() throws -> [URL] {
        let directory = try trashDirectoryURL()
        do {
            return try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == Self.fileExtension }
        } catch {
            throw Failure.cannotList
        }
    }

    private func isInList(_ id: UUID) throws -> Bool {
        try fileManager.fileExists(atPath: fileURL(for: id).path)
    }

    private func trashURL(for id: UUID) throws -> URL {
        try trashDirectoryURL().appending(path: id.uuidString)
            .appendingPathExtension(Self.fileExtension)
    }

    private func remove(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw Failure.cannotDelete
        }
    }
}
