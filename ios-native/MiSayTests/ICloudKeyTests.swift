import CryptoKit
@testable import MiSay
import XCTest

/// 2026-11-25 文字稿金鑰跟 iCloud 鑰匙圈走。只准在模擬器跑：會把加密金鑰與資料夾清掉。
final class ICloudKeyTests: XCTestCase {
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

    func test換新手機_鑰匙圈帶著就讀得到() throws {
        try store.save(Transcript(durationSeconds: 1, rawText: "舊手機寫的"))
        try keyStore.deleteLocalForTesting()

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.transcripts.map(\.rawText), ["舊手機寫的"])
        XCTAssertEqual(loaded.unreadableCount, 0)
    }

    func test鑰匙圈晚到_先搬走的會放回來_新寫的也都在() throws {
        try store.save(Transcript(durationSeconds: 1, rawText: "舊手機寫的"))
        let oldKey = try keyStore.loadOrCreateKey()
        try keyStore.deleteForTesting()
        XCTAssertEqual(try store.loadAll().unreadableCount, 1)
        try store.save(Transcript(durationSeconds: 1, rawText: "新手機寫的"))

        try keyStore.addUnlessPresent(oldKey, inICloud: true)
        let loaded = try store.loadAll()
        XCTAssertEqual(Set(loaded.transcripts.map(\.rawText)), ["舊手機寫的", "新手機寫的"])
        XCTAssertEqual(loaded.unreadableCount, 0)
    }

    func test垃圾桶裡的晚到也放回垃圾桶() throws {
        let transcript = Transcript(durationSeconds: 1, rawText: "丟掉的")
        try store.save(transcript)
        try store.moveToTrash(id: transcript.id)
        let oldKey = try keyStore.loadOrCreateKey()
        try keyStore.deleteForTesting()
        _ = try store.trashedIDs()
        let trash = try store.trashURL(for: transcript.id)
        if FileManager.default.fileExists(atPath: trash.path) {
            try store.setAside(trash)
        }

        try keyStore.addUnlessPresent(oldKey, inICloud: true)
        XCTAssertEqual(try store.loadAll().transcripts, [])
        XCTAssertNotNil(try store.loadFromTrash(id: transcript.id))
    }

    func test別台刪掉鑰匙圈那份_這台打開過的還讀得到() throws {
        try store.save(Transcript(durationSeconds: 1, rawText: "舊手機寫的"))
        let oldKey = try keyStore.loadOrCreateKey()
        try keyStore.deleteForTesting()
        _ = try store.loadAll()
        try keyStore.addUnlessPresent(oldKey, inICloud: true)
        XCTAssertEqual(try store.loadAll().transcripts.count, 1)

        try keyStore.deleteICloudForTesting()
        XCTAssertEqual(try store.loadAll().transcripts.count, 1)
    }

    func test刪除全部資料只刪這台的金鑰_別台那把留著() throws {
        _ = try keyStore.loadOrCreateKey()
        let otherPhone = SymmetricKey(size: .bits256)
        try keyStore.addUnlessPresent(otherPhone, inICloud: true)
        try keyStore.delete()
        XCTAssertEqual(keyStore.otherKeys(), [otherPhone])
    }
}
