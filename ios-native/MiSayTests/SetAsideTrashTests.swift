@testable import MiSay
import XCTest

/// 2026-11-26 overnight 2：垃圾桶與另存檔的三個小毛病。
/// 只准在模擬器跑：setUp 會把舊金鑰與文字稿資料夾清掉。
final class SetAsideTrashTests: XCTestCase {
    private let store = TranscriptStore()
    private let keyStore = TranscriptEncryptionKeyStore()

    override func setUpWithError() throws {
        try keyStore.deleteForTesting()
        try? FileManager.default.removeItem(at: store.directoryURL())
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: store.directoryURL())
        try keyStore.deleteForTesting()
    }

    // MARK: a) 永久刪掉的不再回來

    func test永久刪掉的篇_另存的同一篇一起刪_清單與垃圾桶都不再出現() throws {
        let transcript = Transcript(durationSeconds: 1, rawText: "刪掉的")
        try store.save(transcript)
        try store.moveToTrash(id: transcript.id)
        var older = transcript
        older.rawText = "另存那份"
        try store.write(older, to: setAsideURL(transcript.id.uuidString))
        let broken = try setAsideURL("\(UUID())-\(transcript.id)")
        try Data("壞掉".utf8).write(to: broken)
        let other = try setAsideURL(UUID().uuidString)
        try Data("別篇壞掉".utf8).write(to: other)

        XCTAssertEqual(try store.loadAll().transcripts, [], "垃圾桶還有這篇，另存的不搬回來")
        XCTAssertTrue(try store.deleteFromTrash(id: transcript.id))

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts, [])
        XCTAssertEqual(try store.loadTrash(), [])
        XCTAssertEqual(loaded.unreadableCount, 1, "只剩別篇那份")
        XCTAssertFalse(FileManager.default.fileExists(atPath: broken.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path), "別篇的不准動")
    }

    func test永久刪掉時清單還有這篇_另存的留著() throws {
        let transcript = Transcript(durationSeconds: 1, rawText: "垃圾桶那份")
        try store.save(transcript)
        try store.moveToTrash(id: transcript.id)
        var listed = transcript
        listed.rawText = "清單那份"
        try store.save(listed)
        let file = try setAsideURL(transcript.id.uuidString)
        try store.write(transcript, to: file)

        XCTAssertFalse(try store.deleteFromTrash(id: transcript.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try store.loadAll().transcripts.map(\.rawText), ["清單那份"])
    }

    // MARK: b) 同一篇只算一次

    func test同一篇壞了兩份_只算一篇_清單已經有的不算() throws {
        let missing = UUID()
        try Data("壞掉一".utf8).write(to: setAsideURL(missing.uuidString))
        try Data("壞掉二".utf8).write(to: setAsideURL("\(UUID())-\(missing)"))
        let listed = Transcript(durationSeconds: 1, rawText: "好的")
        try store.save(listed)
        try Data("舊的壞了".utf8).write(to: setAsideURL(listed.id.uuidString))

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["好的"])
        XCTAssertEqual(loaded.unreadableCount, 1)
        XCTAssertEqual(try store.loadAll().unreadableCount, 1, "再讀一次也一樣")
    }

    // MARK: c) 垃圾桶有讀不到的要講

    func test垃圾桶有一篇一時讀不到_算得出沒列的篇數() throws {
        let blocked = Transcript(durationSeconds: 1, rawText: "讀不到的")
        let other = Transcript(durationSeconds: 1, rawText: "好的")
        for transcript in [blocked, other] {
            try store.save(transcript)
            try store.moveToTrash(id: transcript.id)
        }
        let file = try store.trashURL(for: blocked.id)
        defer { try? setPermissions(0o600, of: file) }
        try setPermissions(0, of: file)

        let shown = try store.loadTrash()
        XCTAssertEqual(shown.map(\.rawText), ["好的"])
        XCTAssertEqual(try store.unlistedTrashCount(shown: shown), 1)
        XCTAssertEqual(TrashView.unlistedNote(1), "有 1 篇讀不到，沒列在這裡。")

        try setPermissions(0o600, of: file)
        let again = try store.loadTrash()
        XCTAssertEqual(try store.unlistedTrashCount(shown: again), 0)
    }

    func test垃圾桶與清單都有的那篇_不算沒列() throws {
        let transcript = Transcript(durationSeconds: 1, rawText: "垃圾桶那份")
        try store.save(transcript)
        try store.moveToTrash(id: transcript.id)
        try store.save(transcript)

        let shown = try store.loadTrash()
        XCTAssertEqual(shown, [])
        XCTAssertEqual(try store.unlistedTrashCount(shown: shown), 0)
    }
}

private extension SetAsideTrashTests {
    func setAsideURL(_ name: String) throws -> URL {
        try store.ensuredDirectory(named: TranscriptStore.unreadableDirectoryName)
            .appending(path: name)
            .appendingPathExtension(TranscriptStore.fileExtension)
    }

    func setPermissions(_ mode: Int, of file: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: file.path)
    }
}
