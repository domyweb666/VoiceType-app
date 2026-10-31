@testable import MiSay
import XCTest

/// 片 D1：加密存檔。只准在模擬器跑：setUp 會把加密金鑰與資料夾清掉。
final class TranscriptStoreTests: XCTestCase {
    private let store = TranscriptStore()
    private let keyStore = TranscriptEncryptionKeyStore()

    override func setUpWithError() throws {
        try keyStore.deleteForTesting()
        let directory = try store.directoryURL()
        try? FileManager.default.removeItem(at: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: try store.directoryURL())
        try keyStore.deleteForTesting()
    }

    func test存檔一篇存進去讀得回來而且最新在最上面() throws {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let newDate = Date(timeIntervalSince1970: 2000)
        let older = Transcript(createdAt: oldDate, durationSeconds: 60, rawText: "舊的")
        let newer = Transcript(createdAt: newDate, durationSeconds: 90, rawText: "新的")
        try store.save(older)
        try store.save(newer)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.unreadableCount, 0)
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["新的", "舊的"])
        XCTAssertEqual(loaded.transcripts.first?.durationSeconds, 90)
    }

    func test存檔在磁碟上不是明文() throws {
        let secret = "散步時想到的訂閱制想法"
        let transcript = Transcript(durationSeconds: 10, rawText: secret)
        try store.save(transcript)

        let directory = try store.directoryURL()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        let file = try XCTUnwrap(files.first { $0.pathExtension == TranscriptStore.fileExtension })
        let bytes = try Data(contentsOf: file)
        XCTAssertFalse(bytes.range(of: Data(secret.utf8)) != nil)
        XCTAssertFalse(bytes.range(of: Data("rawText".utf8)) != nil)
    }

    func test存檔改一篇再讀是改過的() throws {
        var transcript = Transcript(durationSeconds: 10, rawText: "原本")
        try store.save(transcript)
        transcript.draftText = "潤飾後"
        transcript.polishModel = "假模型"
        try store.save(transcript)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.count, 1)
        XCTAssertEqual(loaded.transcripts.first?.draftText, "潤飾後")
        XCTAssertEqual(loaded.transcripts.first?.polishModel, "假模型")
    }

    func test存檔刪一篇之後讀不到() throws {
        let transcript = Transcript(durationSeconds: 10, rawText: "要刪的")
        try store.save(transcript)
        try store.delete(id: transcript.id)
        XCTAssertTrue(try store.loadAll().transcripts.isEmpty)
        // 刪不存在的也不算錯
        try store.delete(id: transcript.id)
    }

    func test存檔讀到壞檔時另存不刪其他篇照讀() throws {
        try store.save(Transcript(durationSeconds: 10, rawText: "好的"))
        let directory = try store.directoryURL()
        let broken = directory.appending(path: "broken")
            .appendingPathExtension(TranscriptStore.fileExtension)
        try Data("這不是加密檔".utf8).write(to: broken)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["好的"])
        XCTAssertEqual(loaded.unreadableCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: broken.path))
        let setAside = directory.appending(path: "Unreadable")
            .appending(path: broken.lastPathComponent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: setAside.path))
    }

    func test存檔換一個實例讀得到同一把金鑰的檔() throws {
        try store.save(Transcript(durationSeconds: 10, rawText: "跨實例"))
        let another = TranscriptStore()
        XCTAssertEqual(try another.loadAll().transcripts.first?.rawText, "跨實例")
    }
}
