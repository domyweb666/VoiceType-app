import Foundation

/// 另存在 Unreadable/ 的檔：數有幾個、現在解得開了就搬回去。
/// 退回舊版時，舊版不認得 JSON，會把好好的檔搬到這裡；再更新回來要看得到。
extension TranscriptStore {
    /// UUID 字串的長度：另存的檔名可能是「避撞名的前綴-編號」，從後面取這麼長。
    private static let idStringLength = 36

    /// 另存的檔有幾篇。同一篇只算一次；清單或垃圾桶已經有那篇的不算：那篇好好的，
    /// 算進去的話留下來的重複份搬不回去，橫幅就一直說有讀不到的（2026-11-26 overnight 2）。
    /// 數不到就當還有一個：當成 0，留存錄音的孤兒會被清掉，那可能是讀不到的那篇僅剩的一份。
    func setAsideFileCount() -> Int {
        guard let files = try? setAsideFiles() else {
            return 1
        }
        var unnamedCount = 0
        var missingIDs: Set<UUID> = []
        for file in files {
            guard let id = setAsideID(of: file) else {
                unnamedCount += 1
                continue
            }
            if !isListedOrTrashed(id) {
                missingIDs.insert(id)
            }
        }
        return unnamedCount + missingIDs.count
    }

    /// 讀不到、解不開、搬不動的都留在原地，下次再試，不影響其他篇。
    /// 同一篇搬過兩次的，最後改的那份先搬，另一份留著。
    func restoreSetAside(now: Date = Date()) {
        guard let files = try? setAsideFiles() else {
            return
        }
        var found: [(file: URL, transcript: Transcript)] = []
        for file in files {
            if let transcript = try? read(file) {
                found.append((file, transcript))
            }
        }
        for item in found.sorted(by: { $0.transcript.updatedAt > $1.transcript.updatedAt }) {
            try? putBack(item.transcript, from: item.file, now: now)
        }
    }

    /// 這篇從此哪裡都沒有了（垃圾桶裡永久刪掉）：另存的同一篇一起刪。
    /// 不刪的話，下次讀清單時解得開的那份會被搬回來，刪掉的又出現（2026-11-26 overnight 2）。
    func removeSetAside(id: UUID) throws {
        for file in try setAsideFiles() where setAsideID(of: file) == id {
            do {
                try fileManager.removeItem(at: file)
            } catch {
                throw Failure.cannotDelete
            }
        }
    }

    /// 照內容的 id 放，檔名可能加過避撞名的前綴。清單或垃圾桶已經有這篇就不動，絕不蓋。
    /// 垃圾桶的期限已經過了的也不動：搬回去馬上會被真的刪掉。
    private func putBack(_ transcript: Transcript, from file: URL, now: Date) throws {
        let trashed = try trashURL(for: transcript.id)
        guard try !isInList(transcript.id), !fileManager.fileExists(atPath: trashed.path),
              !Self.isExpired(trashedAt: transcript.trashedAt, now: now)
        else {
            return
        }
        let listed = try fileURL(for: transcript.id)
        try fileManager.moveItem(at: file, to: transcript.trashedAt == nil ? listed : trashed)
    }

    /// 另存的檔是哪一篇：讀得到看內容（跟搬回去用的一樣），讀不到看檔名。都看不出來回 nil。
    private func setAsideID(of file: URL) -> UUID? {
        if let transcript = try? read(file) {
            return transcript.id
        }
        let name = file.deletingPathExtension().lastPathComponent
        return UUID(uuidString: String(name.suffix(Self.idStringLength)))
    }

    /// 查不到就當不在：寧可多算一篇讀不到，也不讓孤兒錄音被清掉。
    private func isListedOrTrashed(_ id: UUID) -> Bool {
        let isListed = (try? isInList(id)) ?? false
        guard let trashed = try? trashURL(for: id) else {
            return isListed
        }
        return isListed || fileManager.fileExists(atPath: trashed.path)
    }

    private func setAsideFiles() throws -> [URL] {
        try transcriptFiles(in: ensuredDirectory(named: Self.unreadableDirectoryName))
    }
}
