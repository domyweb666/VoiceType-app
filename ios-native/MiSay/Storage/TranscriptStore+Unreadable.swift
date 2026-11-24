import Foundation

/// 另存在 Unreadable/ 的檔：數有幾個、現在解得開了就搬回去。
/// 退回舊版時，舊版不認得 JSON，會把好好的檔搬到這裡；再更新回來要看得到。
extension TranscriptStore {
    /// 數不到就當還有一個：當成 0，留存錄音的孤兒會被清掉，那可能是讀不到的那篇僅剩的一份。
    func setAsideFileCount() -> Int {
        (try? setAsideFiles().count) ?? 1
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

    private func setAsideFiles() throws -> [URL] {
        try transcriptFiles(in: ensuredDirectory(named: Self.unreadableDirectoryName))
    }
}
