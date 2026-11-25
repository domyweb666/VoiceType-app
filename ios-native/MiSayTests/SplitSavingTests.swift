@testable import MiSay
import XCTest

/// 片 J3 拆篇的存檔。只准在模擬器跑：setUp 會把舊金鑰與文字稿資料夾清掉。
final class SplitSavingTests: XCTestCase {
    private let store = TranscriptStore()
    private let keyStore = TranscriptEncryptionKeyStore()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let source = Transcript(durationSeconds: 60, rawText: "口語", draftText: "整篇文字稿")
    private let topics = [
        SplitTopic(title: "咖啡", summary: "買咖啡", text: "先買了咖啡。", paragraphs: [1]),
        SplitTopic(title: "散步", summary: "走路", text: "晚上去散步。", paragraphs: [2]),
        SplitTopic(title: "書桌", summary: "整理", text: "整理了書桌。", paragraphs: [3]),
    ]

    override func setUpWithError() throws {
        try keyStore.deleteForTesting()
        try? FileManager.default.removeItem(at: store.directoryURL())
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: store.directoryURL())
        try keyStore.deleteForTesting()
    }

    func test一件事存一篇_原篇一個字不動_第一件事排最上面() throws {
        try store.save(source)
        let before = try Data(contentsOf: store.fileURL(for: source.id))
        XCTAssertEqual(try store.saveSplit(topics, of: source.id, now: now), [])

        XCTAssertEqual(try Data(contentsOf: store.fileURL(for: source.id)), before)
        let stored = try store.loadAll().transcripts
        let pieces = Transcript.derived(of: source.id, in: stored)
        XCTAssertEqual(pieces.map(\.id), topics.map(\.id))
        XCTAssertEqual(pieces.map(\.displayText), topics.map(\.text))
        XCTAssertTrue(pieces.allSatisfy(\.isSplit))
    }

    func test原篇不在了或在垃圾桶_一篇都不存() throws {
        XCTAssertThrowsError(try store.saveSplit(topics, of: source.id)) { error in
            XCTAssertEqual(error as? TranscriptStore.Failure, .notFound)
        }
        try store.save(source)
        try store.moveToTrash(id: source.id)
        XCTAssertThrowsError(try store.saveSplit(topics, of: source.id)) { error in
            XCTAssertEqual(error as? TranscriptStore.Failure, .notFound)
        }
        XCTAssertTrue(try store.listedIDs().isEmpty)
    }

    func test已經有同一篇就不蓋() throws {
        try store.save(source)
        XCTAssertEqual(try store.saveSplit([topics[0]], of: source.id), [])
        try store.update(id: topics[0].id) { $0.draftText = "後來改過的字" }

        XCTAssertEqual(try store.saveSplit(topics, of: source.id), [])
        XCTAssertEqual(try store.load(id: topics[0].id)?.draftText, "後來改過的字")
        XCTAssertEqual(try store.listedIDs().count, topics.count + 1)
    }

    func test一篇沒存成不擋其他篇_再按只存剩下的() throws {
        try store.save(source)
        var session = SplitSheet.Session()
        let result = TopicSplit(topics: topics, unassignedParagraphs: 0)
        session.show(result, from: "原稿", hasEarlierPieces: false)
        // 那個檔名被一個資料夾佔著，讀不到也寫不進去。
        let blocked = try store.fileURL(for: topics[1].id)
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)

        let failedIDs = try store.saveSplit(session.chosenTopics, of: source.id)
        XCTAssertEqual(failedIDs, [topics[1].id])
        session.recordSave(of: session.chosenTopics, failedIDs: failedIDs)
        XCTAssertEqual(session.savedIDs, [topics[0].id, topics[2].id])
        XCTAssertEqual(session.chosenTopics, [topics[1]])
        XCTAssertEqual(session.saveFailure, SplitSheet.Session.unsavedNote(count: 1))

        try FileManager.default.removeItem(at: blocked)
        let retried = try store.saveSplit(session.chosenTopics, of: source.id)
        session.recordSave(of: session.chosenTopics, failedIDs: retried)
        XCTAssertTrue(session.unsavedTopics.isEmpty)
        XCTAssertNil(session.saveFailure)
        XCTAssertEqual(try store.listedIDs(), Set(topics.map(\.id) + [source.id]))
    }
}
