import CryptoKit
@testable import MiSay
import XCTest

/// 片 S2-9：刪除全部資料。只准在模擬器跑：會清掉 App 自己的文字稿、待轉錄、留存錄音資料夾。
@MainActor
final class EraseAllDataTests: XCTestCase {
    private let keyStore = APIKeyStore()
    private let fakeKey = "sk-test-假金鑰-刪全部用"

    override func tearDownWithError() throws {
        try keyStore.delete()
    }

    func test刪除全部資料文字稿與錄音都沒了金鑰還在() throws {
        try keyStore.save(fakeKey)
        let transcript = Transcript(durationSeconds: 60, rawText: "要被刪掉的口語稿")
        try TranscriptStore().save(transcript)
        let trashed = Transcript(durationSeconds: 60, rawText: "垃圾桶裡的")
        try TranscriptStore().save(trashed)
        try TranscriptStore().moveToTrash(id: trashed.id)
        let pendingFile = try PendingRecordings().directoryURL().appending(path: "erase-test.wav")
        try Data(repeating: 0, count: 44).write(to: pendingFile)
        let retainedFile = try RetainedRecordings().url(for: transcript.id)
        try Data(repeating: 0, count: 44).write(to: retainedFile)

        try EraseAllDataSection.eraseAll()

        XCTAssertEqual(try TranscriptStore().loadAll().transcripts, [])
        XCTAssertEqual(try TranscriptStore().trashedIDs(), [], "垃圾桶也要清掉")
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingFile.path))
        XCTAssertFalse(RetainedRecordings().exists(for: transcript.id))
        XCTAssertEqual(try keyStore.read(), fakeKey, "金鑰另有鈕，不准一起刪")
    }

    func test沒有舊金鑰也刪得乾淨_有舊金鑰會一起刪() throws {
        let legacyKeyStore = TranscriptEncryptionKeyStore()
        try legacyKeyStore.deleteForTesting()
        try TranscriptStore().save(Transcript(durationSeconds: 60, rawText: "要被刪掉的"))
        try EraseAllDataSection.eraseAll()
        XCTAssertEqual(try TranscriptStore().loadAll().transcripts, [])

        try legacyKeyStore.saveForTesting(SymmetricKey(size: .bits256))
        try EraseAllDataSection.eraseAll()
        // 金鑰還在的話，再放一把會撞到。
        XCTAssertNoThrow(try legacyKeyStore.saveForTesting(SymmetricKey(size: .bits256)))
        try legacyKeyStore.deleteForTesting()
    }

    /// 刪光之前就開著的編輯頁，刪光之後再打字：存檔被擋下來，刪掉的那篇不會跑回來。
    func test刪除全部資料後_之前開著的編輯頁存不回去() throws {
        let store = TranscriptStore()
        let transcript = Transcript(durationSeconds: 60, rawText: "開著編輯頁的那篇")
        let opened = TranscriptStore.eraseGeneration
        try store.save(transcript, openedInGeneration: opened)

        try EraseAllDataSection.eraseAll()

        XCTAssertThrowsError(try store.save(transcript, openedInGeneration: opened)) { error in
            XCTAssertEqual(error as? TranscriptStore.Failure, .notFound)
        }
        XCTAssertNil(try store.load(id: transcript.id), "刪掉的那篇不准跑回來")
        XCTAssertEqual(try store.loadAll().transcripts, [])
    }

    /// 刪光之後才開的篇照常存得進去。
    func test刪除全部資料後_新開的篇照常能存() throws {
        try EraseAllDataSection.eraseAll()
        let store = TranscriptStore()
        let draft = Transcript.blankDraft()

        try store.save(draft, openedInGeneration: TranscriptStore.eraseGeneration)

        XCTAssertEqual(try store.load(id: draft.id)?.id, draft.id)
        try EraseAllDataSection.eraseAll()
    }
}
