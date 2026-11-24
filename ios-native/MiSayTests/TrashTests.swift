@testable import MiSay
import XCTest

/// 2026-11-24 垃圾桶。只准在模擬器跑：setUp 會把加密金鑰與文字稿資料夾清掉。
final class TrashTests: XCTestCase {
    private let store = TranscriptStore()
    private let keyStore = TranscriptEncryptionKeyStore()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    override func setUpWithError() throws {
        try keyStore.deleteForTesting()
        try? FileManager.default.removeItem(at: store.directoryURL())
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: store.directoryURL())
        try keyStore.deleteForTesting()
    }

    func test丟進垃圾桶清單看不到_放回來內容一樣() throws {
        var transcript = Transcript(durationSeconds: 10, rawText: "口語", draftText: "文字稿")
        transcript.title = "標題"
        try store.save(transcript)
        let saved = try XCTUnwrap(store.load(id: transcript.id))

        try store.moveToTrash(id: transcript.id, now: now)
        XCTAssertEqual(try store.loadAll().transcripts, [])
        XCTAssertNil(try store.load(id: transcript.id))
        XCTAssertEqual(try store.loadTrash().map(\.id), [transcript.id])
        XCTAssertEqual(try store.loadTrash().first?.trashedAt, now)
        XCTAssertEqual(try store.trashedIDs(), [transcript.id])

        try store.restoreFromTrash(id: transcript.id)
        XCTAssertEqual(try store.loadAll().transcripts, [saved])
        XCTAssertEqual(try store.trashedIDs(), [])
    }

    func test丟進去的是存檔裡最新的那份_不在了就不用丟() throws {
        var transcript = Transcript(durationSeconds: 10, rawText: "舊的")
        try store.save(transcript)
        transcript.rawText = "新的"
        try store.save(transcript)
        try store.moveToTrash(id: transcript.id, now: now)
        XCTAssertEqual(try store.loadTrash().first?.rawText, "新的")

        try store.moveToTrash(id: UUID(), now: now)
        XCTAssertEqual(try store.trashedIDs().count, 1)
    }

    func test垃圾桶的檔也加密() throws {
        let secret = "丟掉的想法"
        let transcript = Transcript(durationSeconds: 10, rawText: secret)
        try store.save(transcript)
        try store.moveToTrash(id: transcript.id, now: now)
        let files = try FileManager.default.contentsOfDirectory(
            at: store.trashDirectoryURL(),
            includingPropertiesForKeys: nil
        )
        let bytes = try Data(contentsOf: XCTUnwrap(files.first))
        XCTAssertNil(bytes.range(of: Data(secret.utf8)))
    }

    func test放滿三十天才真的刪_沒記時間的不刪() throws {
        let fresh = Transcript(durationSeconds: 10, rawText: "29 天")
        let old = Transcript(durationSeconds: 10, rawText: "30 天")
        for transcript in [fresh, old] {
            try store.save(transcript)
        }
        try store.moveToTrash(id: fresh.id, now: now.addingTimeInterval(-29 * day))
        try store.moveToTrash(id: old.id, now: now.addingTimeInterval(-30 * day))

        XCTAssertEqual(try store.deleteExpiredTrash(now: now), [old.id])
        XCTAssertEqual(try store.trashedIDs(), [fresh.id])
        XCTAssertFalse(TranscriptStore.isExpired(trashedAt: nil, now: now))
    }

    func test兩邊都有時以清單那份為準_到期只刪垃圾桶那份() throws {
        let transcript = Transcript(durationSeconds: 10, rawText: "垃圾桶那份")
        try store.save(transcript)
        try store.moveToTrash(id: transcript.id, now: now.addingTimeInterval(-40 * day))
        var listed = transcript
        listed.rawText = "清單那份"
        try store.save(listed)

        XCTAssertEqual(try store.loadTrash(), [])
        XCTAssertThrowsError(try store.restoreFromTrash(id: transcript.id))
        XCTAssertEqual(try store.load(id: transcript.id)?.rawText, "清單那份")
        // 清單還有這篇，錄音不能跟著刪，所以不回報。
        XCTAssertEqual(try store.deleteExpiredTrash(now: now), [])
        XCTAssertEqual(try store.trashedIDs(), [])
        XCTAssertEqual(try store.loadAll().transcripts.map(\.rawText), ["清單那份"])
    }

    func test垃圾桶裡解不開的另存不刪() throws {
        let id = UUID()
        let broken = try store.trashDirectoryURL().appending(path: id.uuidString)
            .appendingPathExtension(TranscriptStore.fileExtension)
        try Data("這不是加密檔".utf8).write(to: broken)
        XCTAssertEqual(try store.trashedIDs(), [id], "還沒搬走前錄音也要保住")

        XCTAssertEqual(try store.deleteExpiredTrash(now: now), [])
        let setAside = try store.directoryURL().appending(path: "Unreadable")
            .appending(path: broken.lastPathComponent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: setAside.path))
        // 算進讀不到的篇數，留存錄音就不會刪孤兒。
        XCTAssertEqual(try store.loadAll().unreadableCount, 1)
    }

    func test垃圾桶裡的篇錄音不算孤兒() {
        let trashed = UUID()
        let orphan = UUID()
        let doomed = RetainedRecordings.idsToDelete(
            retainedIDs: [trashed, orphan],
            transcripts: [],
            trashedIDs: [trashed],
            deletesOrphans: true,
            now: now,
            availableBytes: 10
        )
        XCTAssertEqual(doomed, [orphan])
    }

    func test清單刪除_空白新文稿直接刪_其他進垃圾桶() throws {
        let blank = Transcript.blankDraft()
        var titled = Transcript.blankDraft()
        titled.title = "只有標題"
        let written = Transcript(durationSeconds: 0, rawText: "", draftText: "寫了字")
        for transcript in [blank, titled, written] {
            try store.save(transcript)
            try TranscriptListView.discard(id: transcript.id)
        }
        XCTAssertEqual(try store.loadAll().transcripts, [])
        XCTAssertEqual(try store.trashedIDs(), [titled.id, written.id])
    }

    func test還有幾天() {
        XCTAssertEqual(TranscriptStore.daysLeft(trashedAt: now, now: now), 30)
        let almost = now.addingTimeInterval(29.5 * day)
        XCTAssertEqual(TranscriptStore.daysLeft(trashedAt: now, now: almost), 1)
        let late = now.addingTimeInterval(31 * day)
        XCTAssertEqual(TrashView.daysLeftText(trashedAt: now, now: late), "今天會刪")
        XCTAssertEqual(TrashView.daysLeftText(trashedAt: now, now: now), "還有 30 天")
        XCTAssertNil(TrashView.daysLeftText(trashedAt: nil, now: now))
    }

    func test改存檔裡的一篇_不在了就不存() throws {
        let transcript = Transcript(durationSeconds: 10, rawText: "原本")
        try store.save(transcript)
        try store.update(id: transcript.id) { $0.title = "標題" }
        XCTAssertEqual(try store.load(id: transcript.id)?.title, "標題")
        XCTAssertThrowsError(try store.update(id: UUID()) { $0.title = "標題" })
        XCTAssertEqual(try store.loadAll().transcripts.count, 1)
    }

    func test垃圾桶已經有同一篇_留較新的正文_另一份留成版本() throws {
        var transcript = Transcript(durationSeconds: 10, rawText: "口語", draftText: "新稿")
        transcript.updatedAt = now
        try store.save(transcript)
        try store.moveToTrash(id: transcript.id, now: now)
        transcript.draftText = "舊備份的稿"
        transcript.updatedAt = now.addingTimeInterval(-day)
        try store.save(transcript)
        try store.moveToTrash(id: transcript.id, now: now)

        let kept = try XCTUnwrap(store.loadTrash().first)
        XCTAssertEqual(kept.draftText, "新稿")
        XCTAssertEqual(kept.versions?.map(\.text), ["舊備份的稿"])
        XCTAssertNil(try store.load(id: transcript.id))
    }
}
