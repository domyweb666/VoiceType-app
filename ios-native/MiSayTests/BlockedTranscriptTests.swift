import CryptoKit
@testable import MiSay
import Security
import XCTest

/// 2026-11-25 審查：一篇讀不到不拖累別篇，另存在 Unreadable/ 的解得開了會搬回來。
/// 只准在模擬器跑：setUp 會把舊金鑰與文字稿資料夾清掉。
final class BlockedTranscriptTests: XCTestCase {
    private let store = TranscriptStore()
    private let keyStore = TranscriptEncryptionKeyStore()
    private let legacyKey = SymmetricKey(size: .bits256)
    /// 鑰匙圈還沒解鎖的樣子。
    private let lockedStore = TranscriptStore(
        keyStore: TranscriptEncryptionKeyStore(readFailureForTesting: errSecInteractionNotAllowed)
    )

    override func setUpWithError() throws {
        try keyStore.deleteForTesting()
        try? FileManager.default.removeItem(at: store.directoryURL())
        try keyStore.saveForTesting(legacyKey)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: store.directoryURL())
        try keyStore.deleteForTesting()
    }

    // MARK: 一時讀不到

    func test一篇一時讀不到_其他照讀_算進讀不到_檔不動() throws {
        let blocked = Transcript(durationSeconds: 1, rawText: "讀不到的")
        try store.save(blocked)
        try store.save(Transcript(durationSeconds: 1, rawText: "好的"))
        let broken = try store.directoryURL().appending(path: "broken")
            .appendingPathExtension(TranscriptStore.fileExtension)
        try Data("壞掉".utf8).write(to: broken)
        let file = try store.fileURL(for: blocked.id)
        try setPermissions(0, of: file)
        defer { try? setPermissions(0o600, of: file) }

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["好的"])
        XCTAssertEqual(loaded.blockedCount, 1)
        XCTAssertEqual(loaded.unreadableCount, 2, "一時讀不到一篇、另存一篇")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(try store.listedIDs().contains(blocked.id), "匯入備份時算手機上已經有")

        try setPermissions(0o600, of: file)
        let again = try store.loadAll()
        XCTAssertEqual(Set(again.transcripts.map(\.rawText)), ["好的", "讀不到的"])
        XCTAssertEqual(again.blockedCount, 0)
    }

    func test垃圾桶一篇一時讀不到就跳過_檔不動_全讀不到才丟錯() throws {
        let blocked = Transcript(durationSeconds: 1, rawText: "讀不到的")
        let other = Transcript(durationSeconds: 1, rawText: "好的")
        for transcript in [blocked, other] {
            try store.save(transcript)
            try store.moveToTrash(id: transcript.id)
        }
        let file = try store.trashURL(for: blocked.id)
        let otherFile = try store.trashURL(for: other.id)
        defer {
            try? setPermissions(0o600, of: file)
            try? setPermissions(0o600, of: otherFile)
        }

        try setPermissions(0, of: file)
        XCTAssertEqual(try store.loadTrash().map(\.rawText), ["好的"])
        XCTAssertEqual(try store.deleteExpiredTrash(), [])
        XCTAssertEqual(try store.trashedIDs(), [blocked.id, other.id])

        try setPermissions(0, of: otherFile)
        XCTAssertThrowsError(try store.loadTrash())
    }

    func test數不到另存的檔_當成還有一篇_清單照讀() throws {
        try store.save(Transcript(durationSeconds: 1, rawText: "好的"))
        let directory = try unreadableDirectory()
        try setPermissions(0, of: directory)
        defer { try? setPermissions(0o700, of: directory) }

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["好的"])
        XCTAssertEqual(loaded.unreadableCount, 1, "孤兒錄音清理要擋住")
    }

    func test換檔寫回失敗_這次仍讀得到_加密的原檔還在() throws {
        let transcript = Transcript(durationSeconds: 1, rawText: "還沒換的")
        let file = try store.fileURL(for: transcript.id)
        let sealed = try seal(transcript)
        try sealed.write(to: file)
        let directory = try store.directoryURL()
        try setPermissions(0o500, of: directory)
        defer { try? setPermissions(0o700, of: directory) }

        XCTAssertEqual(try store.loadAll().transcripts.map(\.rawText), ["還沒換的"])
        XCTAssertEqual(try Data(contentsOf: file), sealed)

        try setPermissions(0o700, of: directory)
        XCTAssertEqual(try store.loadAll().transcripts.map(\.rawText), ["還沒換的"])
        XCTAssertNotEqual(try Data(contentsOf: file), sealed, "寫得進去了就換成 JSON")
    }

    func test換到一半鑰匙圈讀不到_兩種檔都不動_之後都讀得到() throws {
        let done = Transcript(durationSeconds: 1, rawText: "換好的")
        let waiting = Transcript(durationSeconds: 1, rawText: "還沒換的")
        try store.save(done)
        let sealed = try seal(waiting)
        try sealed.write(to: store.fileURL(for: waiting.id))
        let json = try Data(contentsOf: store.fileURL(for: done.id))

        XCTAssertThrowsError(try lockedStore.loadAll()) { error in
            XCTAssertEqual(error as? TranscriptStore.Failure, .keychainUnavailable)
        }
        XCTAssertEqual(try lockedStore.load(id: done.id)?.rawText, "換好的")
        XCTAssertEqual(try Data(contentsOf: store.fileURL(for: done.id)), json)
        XCTAssertEqual(try Data(contentsOf: store.fileURL(for: waiting.id)), sealed)

        let loaded = try store.loadAll()
        XCTAssertEqual(Set(loaded.transcripts.map(\.rawText)), ["換好的", "還沒換的"])
        XCTAssertEqual(loaded.unreadableCount, 0)
    }
}

/// 另存的搬回來。
extension BlockedTranscriptTests {
    func test另存的讀得到了就搬回清單_檔名加過前綴也照內容的編號放() throws {
        let transcript = Transcript(durationSeconds: 1, rawText: "搬回來的")
        let file = try setAsideURL("\(UUID())-\(transcript.id)")
        try store.write(transcript, to: file)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["搬回來的"])
        XCTAssertEqual(loaded.unreadableCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try store.load(id: transcript.id)?.rawText, "搬回來的")
    }

    func test另存的原本在垃圾桶_搬回垃圾桶_過期的留著不動() throws {
        var trashed = Transcript(durationSeconds: 1, rawText: "丟掉的")
        trashed.trashedAt = Date()
        try store.write(trashed, to: setAsideURL(trashed.id.uuidString))
        var expired = Transcript(durationSeconds: 1, rawText: "丟很久的")
        expired.trashedAt = Date(timeIntervalSince1970: 1000)
        let expiredFile = try setAsideURL(expired.id.uuidString)
        try store.write(expired, to: expiredFile)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts, [])
        XCTAssertEqual(loaded.unreadableCount, 1)
        XCTAssertEqual(try store.loadTrash().map(\.rawText), ["丟掉的"])
        XCTAssertEqual(try store.deleteExpiredTrash(), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: expiredFile.path))
    }

    func test清單或垃圾桶已經有同一篇_另存的不搬也不蓋() throws {
        let listed = Transcript(durationSeconds: 1, rawText: "清單那份")
        let trashed = Transcript(durationSeconds: 1, rawText: "垃圾桶那份")
        for transcript in [listed, trashed] {
            try store.save(transcript)
            var older = transcript
            older.rawText = "另存那份"
            try store.write(older, to: setAsideURL(transcript.id.uuidString))
        }
        try store.moveToTrash(id: trashed.id)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["清單那份"])
        XCTAssertEqual(loaded.unreadableCount, 0, "那兩篇好好的，留著的重複份不算讀不到")
        XCTAssertEqual(try store.loadTrash().map(\.rawText), ["垃圾桶那份"])
    }

    func test同一篇另存兩份_搬最後改的_另一份留著() throws {
        var older = Transcript(durationSeconds: 1, rawText: "舊的")
        older.updatedAt = Date(timeIntervalSince1970: 1000)
        var newer = older
        newer.rawText = "新的"
        newer.updatedAt = Date(timeIntervalSince1970: 2000)
        try store.write(older, to: setAsideURL(older.id.uuidString))
        try store.write(newer, to: setAsideURL("\(UUID())-\(older.id)"))

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["新的"])
        XCTAssertEqual(loaded.unreadableCount, 0, "留著的那份清單已經有，不算讀不到")
    }

    func test另存的加密檔_鑰匙圈讀不到就留著_不影響別篇_讀得到了才搬() throws {
        try store.save(Transcript(durationSeconds: 1, rawText: "好的"))
        let sealed = Transcript(durationSeconds: 1, rawText: "加密的")
        let file = try setAsideURL(sealed.id.uuidString)
        try seal(sealed).write(to: file)

        let locked = try lockedStore.loadAll()
        XCTAssertEqual(locked.transcripts.map(\.rawText), ["好的"])
        XCTAssertEqual(locked.unreadableCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let loaded = try store.loadAll()
        XCTAssertEqual(Set(loaded.transcripts.map(\.rawText)), ["好的", "加密的"])
        XCTAssertEqual(loaded.unreadableCount, 0)
    }

    func test備份區的話_讀不到的不說成全部_也不說沒有() {
        XCTAssertTrue(BackupSection.lead(count: 3, unreadable: 0).contains("全部 3 篇"))
        XCTAssertTrue(BackupSection.lead(count: 3, unreadable: 1).contains("讀得到的 3 篇"))
        XCTAssertTrue(BackupSection.lead(count: 0, unreadable: 2).contains("原檔已保留"))
        XCTAssertEqual(BackupSection.lead(count: 0, unreadable: 0), "還沒有文字稿可以備份。")
    }
}

private extension BlockedTranscriptTests {
    func unreadableDirectory() throws -> URL {
        try store.ensuredDirectory(named: TranscriptStore.unreadableDirectoryName)
    }

    func setAsideURL(_ name: String) throws -> URL {
        try unreadableDirectory().appending(path: name)
            .appendingPathExtension(TranscriptStore.fileExtension)
    }

    func seal(_ transcript: Transcript) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(transcript)
        return try XCTUnwrap(AES.GCM.seal(json, using: legacyKey).combined)
    }

    func setPermissions(_ mode: Int, of file: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: file.path)
    }
}
