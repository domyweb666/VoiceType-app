import CryptoKit
@testable import MiSay
import Security
import XCTest

/// 2026-11-25 不另外加密：舊版加密的文字稿、垃圾桶、進度檔讀得到、換得成 JSON，一時讀不到時一個檔都不動。
/// 只准在模擬器跑：setUp 會把舊金鑰與文字稿資料夾清掉。
final class LegacyTranscriptTests: XCTestCase {
    private let store = TranscriptStore()
    private let keyStore = TranscriptEncryptionKeyStore()
    private let legacyKey = SymmetricKey(size: .bits256)
    /// 鑰匙圈還沒解鎖的樣子。
    private let lockedKeyStore = TranscriptEncryptionKeyStore(
        readFailureForTesting: errSecInteractionNotAllowed
    )

    private var lockedStore: TranscriptStore {
        TranscriptStore(keyStore: lockedKeyStore)
    }

    override func setUpWithError() throws {
        try keyStore.deleteForTesting()
        try? FileManager.default.removeItem(at: store.directoryURL())
        try keyStore.saveForTesting(legacyKey)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: store.directoryURL())
        try keyStore.deleteForTesting()
    }

    func test舊加密檔讀得到_換成原始JSON_金鑰刪了仍讀得到() throws {
        let id = UUID()
        let json = try makeJSON(id: id, text: "舊的口語稿")
        let file = try store.fileURL(for: id)
        try seal(json).write(to: file)

        XCTAssertEqual(try store.load(id: id)?.rawText, "舊的口語稿")
        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["舊的口語稿"])
        XCTAssertEqual(loaded.unreadableCount, 0)
        XCTAssertEqual(try Data(contentsOf: file), json, "原始內容照搬，不認得的欄位也在")

        try keyStore.deleteForTesting()
        XCTAssertEqual(try store.loadAll().transcripts.map(\.rawText), ["舊的口語稿"])
    }

    func test密文第一個位元組剛好是大括號也解得開() throws {
        let id = UUID()
        let json = try makeJSON(id: id, text: "運氣不好")
        let nonce = try AES.GCM.Nonce(data: Data("{".utf8) + Data(count: 11))
        let sealed = try XCTUnwrap(AES.GCM.seal(json, using: legacyKey, nonce: nonce).combined)
        XCTAssertEqual(sealed.first, Data("{".utf8).first)
        try sealed.write(to: store.fileURL(for: id))

        XCTAssertEqual(try store.loadAll().transcripts.map(\.id), [id])
    }

    func test垃圾桶的舊加密檔讀得到_換成JSON_金鑰刪了仍讀得到() throws {
        let id = UUID()
        let json = try makeJSON(id: id, text: "丟掉的")
        let file = try trashURL(for: id)
        try seal(json).write(to: file)

        assertFails(.keychainUnavailable) { try lockedStore.loadTrash() }
        XCTAssertEqual(try store.trashedIDs(), [id], "鑰匙圈讀不到時不搬走")

        XCTAssertEqual(try store.loadTrash().map(\.rawText), ["丟掉的"])
        XCTAssertEqual(try Data(contentsOf: file), json)
        try keyStore.deleteForTesting()
        XCTAssertEqual(try store.loadTrash().map(\.rawText), ["丟掉的"])
    }

    func test鑰匙圈還沒解鎖_不搬走也不准蓋掉() throws {
        let id = UUID()
        let sealed = try seal(makeJSON(id: id, text: "還沒換的"))
        let file = try store.fileURL(for: id)
        try sealed.write(to: file)

        assertFails(.keychainUnavailable) { try lockedStore.loadAll() }
        assertFails(.keychainUnavailable) { try lockedStore.load(id: id) }
        let other = Transcript(id: id, durationSeconds: 1, rawText: "蓋過去")
        assertFails(.keychainUnavailable) { try lockedStore.save(other) }
        assertFails(.keychainUnavailable) { try lockedStore.moveToTrash(id: id) }
        XCTAssertEqual(try Data(contentsOf: file), sealed)
        XCTAssertEqual(try store.loadAll().transcripts.map(\.rawText), ["還沒換的"])
    }

    func test鑰匙圈還沒解鎖_存新的一篇與讀JSON不受影響() throws {
        try lockedStore.save(Transcript(durationSeconds: 1, rawText: "新的"))
        XCTAssertEqual(try lockedStore.loadAll().transcripts.map(\.rawText), ["新的"])
    }

    func test檔案一時讀不到_不搬走也不准蓋掉() throws {
        let transcript = Transcript(durationSeconds: 1, rawText: "原本的")
        try store.save(transcript)
        let file = try store.fileURL(for: transcript.id)
        try setPermissions(0, of: file)
        defer { try? setPermissions(0o600, of: file) }

        assertFails(.cannotRead) { try store.loadAll() }
        assertFails(.cannotRead) { try store.load(id: transcript.id) }
        assertFails(.cannotRead) { try store.save(transcript) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        try setPermissions(0o600, of: file)
        XCTAssertEqual(try store.loadAll().transcripts.map(\.rawText), ["原本的"])
    }

    @MainActor
    func test整理存回時存檔一時讀不到就不存_別篇讀不到不影響() throws {
        var transcript = Transcript(durationSeconds: 1, rawText: "口語")
        transcript.title = "人取的標題"
        let other = Transcript(durationSeconds: 1, rawText: "別篇")
        try store.save(transcript)
        try store.save(other)
        let file = try store.fileURL(for: transcript.id)
        let otherFile = try store.fileURL(for: other.id)
        defer {
            try? setPermissions(0o600, of: file)
            try? setPermissions(0o600, of: otherFile)
        }
        let queue = TranscriptionQueue()
        var working = transcript
        working.title = nil
        working.draftText = "潤飾好的"

        try setPermissions(0, of: file)
        do {
            try queue.saveKeepingUserFields(&working)
            XCTFail("讀不到存檔時不該存")
        } catch {
            XCTAssertEqual(error as? TranscriptStore.Failure, .cannotRead)
        }
        try setPermissions(0o600, of: file)
        XCTAssertNil(try store.load(id: transcript.id)?.draftText)

        try setPermissions(0, of: otherFile)
        try queue.saveKeepingUserFields(&working)
        let saved = try XCTUnwrap(store.load(id: transcript.id))
        XCTAssertEqual(saved.title, "人取的標題")
        XCTAssertEqual(saved.draftText, "潤飾好的")
    }

    func test沒有舊金鑰或金鑰對不上_另存不刪() throws {
        let file = try store.fileURL(for: UUID())
        let sealed = try seal(makeJSON(id: UUID(), text: "解不開"))
        try sealed.write(to: file)
        try keyStore.deleteForTesting()
        XCTAssertEqual(try store.loadAll().unreadableCount, 1)
        XCTAssertEqual(try Data(contentsOf: setAsideURL(of: file)), sealed)

        let other = try store.fileURL(for: UUID())
        try sealed.write(to: other)
        try keyStore.saveForTesting(SymmetricKey(size: .bits256))
        XCTAssertEqual(try store.loadAll().unreadableCount, 2)
        XCTAssertEqual(try Data(contentsOf: setAsideURL(of: other)), sealed)
    }

    func test是JSON但不是文字稿_另存不刪_不用問鑰匙圈() throws {
        let file = try store.fileURL(for: UUID())
        let bytes = Data(#"{"something":1}"#.utf8)
        try bytes.write(to: file)

        let loaded = try lockedStore.loadAll()
        XCTAssertEqual(loaded.transcripts, [])
        XCTAssertEqual(loaded.unreadableCount, 1)
        XCTAssertEqual(try Data(contentsOf: setAsideURL(of: file)), bytes)
    }

    func test蓋過壞檔之前先另存_以前搬過的也留著() throws {
        let transcript = Transcript(durationSeconds: 1, rawText: "新打的")
        let file = try store.fileURL(for: transcript.id)
        for broken in ["壞掉一", "壞掉二"] {
            try Data(broken.utf8).write(to: file)
            try store.save(transcript)
        }
        XCTAssertEqual(try store.load(id: transcript.id)?.rawText, "新打的")
        let setAside = try FileManager.default.contentsOfDirectory(
            at: setAsideURL(of: file).deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )
        let contents = try Set(setAside.map { try Data(contentsOf: $0) })
        XCTAssertEqual(contents, [Data("壞掉一".utf8), Data("壞掉二".utf8)])
    }

    func test舊加密的進度檔讀得到_再存變JSON_鑰匙圈讀不到不當成空的() throws {
        let recording = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).wav")
        let url = RecordingTranscriptionJob.progressURL(for: recording)
        defer { try? FileManager.default.removeItem(at: url) }
        var progress = RecordingTranscriptionJob.Progress()
        progress.segmentTexts = [0: "第一段。"]
        let sealed = try seal(JSONEncoder().encode(progress))
        try sealed.write(to: url)

        let locked = RecordingTranscriptionJob(keyStore: lockedKeyStore)
        XCTAssertThrowsError(try locked.loadProgress(for: recording))
        XCTAssertThrowsError(try locked.transcriptID(forRecordingAt: recording))
        XCTAssertEqual(try Data(contentsOf: url), sealed)

        let job = RecordingTranscriptionJob()
        XCTAssertEqual(try job.loadProgress(for: recording), progress)
        try job.saveProgress(progress, for: recording)
        try keyStore.deleteForTesting()
        XCTAssertEqual(try job.loadProgress(for: recording), progress)
        XCTAssertEqual(try locked.loadProgress(for: recording), progress, "JSON 不用問鑰匙圈")
    }
}

private extension LegacyTranscriptTests {
    func assertFails(
        _ expected: TranscriptStore.Failure,
        line: UInt = #line,
        _ work: () throws -> some Any
    ) {
        XCTAssertThrowsError(try work(), line: line) { error in
            XCTAssertEqual(error as? TranscriptStore.Failure, expected, line: line)
        }
    }

    /// 帶一個現在的米說不認得的欄位：換檔不准掉。
    func makeJSON(id: UUID, text: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let transcript = Transcript(id: id, durationSeconds: 1, rawText: text)
        let object = try JSONSerialization.jsonObject(with: encoder.encode(transcript))
        var fields = try XCTUnwrap(object as? [String: Any])
        fields["someFutureField"] = "以後才有的欄位"
        return try JSONSerialization.data(withJSONObject: fields)
    }

    func seal(_ data: Data) throws -> Data {
        try XCTUnwrap(AES.GCM.seal(data, using: legacyKey).combined)
    }

    func trashURL(for id: UUID) throws -> URL {
        try store.trashDirectoryURL().appending(path: id.uuidString)
            .appendingPathExtension(TranscriptStore.fileExtension)
    }

    func setAsideURL(of file: URL) throws -> URL {
        try store.directoryURL().appending(path: "Unreadable")
            .appending(path: file.lastPathComponent)
    }

    func setPermissions(_ mode: Int, of file: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: file.path)
    }
}
