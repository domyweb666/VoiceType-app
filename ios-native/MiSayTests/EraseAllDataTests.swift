@testable import MiSay
import XCTest

/// 片 S2-9：刪除全部資料。只准在模擬器跑：會清掉 App 自己的文字稿、待轉錄、留存錄音資料夾。
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
        let pendingFile = try PendingRecordings().directoryURL().appending(path: "erase-test.wav")
        try Data(repeating: 0, count: 44).write(to: pendingFile)
        let retainedFile = try RetainedRecordings().url(for: transcript.id)
        try Data(repeating: 0, count: 44).write(to: retainedFile)

        try EraseAllDataSection.eraseAll()

        XCTAssertEqual(try TranscriptStore().loadAll().transcripts, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingFile.path))
        XCTAssertFalse(RetainedRecordings().exists(for: transcript.id))
        XCTAssertEqual(try keyStore.read(), fakeKey, "金鑰另有鈕，不准一起刪")
    }
}
