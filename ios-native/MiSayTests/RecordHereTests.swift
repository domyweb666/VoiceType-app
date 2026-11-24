@testable import MiSay
import XCTest

/// 2026-11-24 Y4 補錄不離開：接回去的順序、正在打字先等、接不上就留成獨立一篇。順便測標題欄的純函式。
/// 只准在模擬器跑：會寫進歷史資料夾；每條自己清掉自己存的。
@MainActor
final class RecordHereTests: XCTestCase {
    private let store = TranscriptStore()
    private var target = Transcript(durationSeconds: 0, rawText: "")
    private var added = Transcript(durationSeconds: 0, rawText: "")
    private var isTyping = false

    override func setUp() async throws {
        target = Transcript(durationSeconds: 60, rawText: "口語", draftText: "第一段。\n\n第二段。")
        added = Transcript(durationSeconds: 30, rawText: "口語補", draftText: "補的。")
        try store.save(target)
        try store.save(added)
    }

    override func tearDown() async throws {
        try store.delete(id: target.id)
        try store.delete(id: added.id)
    }

    func test那篇沒開著_直接接進存檔_獨立那篇刪掉() throws {
        let queue = makeQueue(at: InsertionPoint(offset: 4, in: "第一段。\n\n第二段。"))
        XCTAssertEqual(queue.mergeIntoAppendTarget(added).id, target.id)
        XCTAssertEqual(try stored(target.id)?.draftText, "第一段。\n\n補的。\n\n第二段。")
        XCTAssertNil(try stored(added.id))
        XCTAssertFalse(queue.hasUnfinishedAppend(to: target.id))
    }

    func test那篇正在打字_先等_獨立那篇還在_收鍵盤才接() throws {
        let queue = makeQueue(at: nil)
        isTyping = true
        queue.openEditor(
            TranscriptionQueue.OpenEditor(token: UUID()) { [self] added, insertion in
                guard !isTyping else {
                    return .busy
                }
                var updated = target
                _ = TranscriptionQueue.append(added, to: &updated, at: insertion)
                return (try? store.save(updated)) == nil ? .refused : .taken(updated)
            },
            for: target.id
        )
        XCTAssertEqual(queue.mergeIntoAppendTarget(added).id, added.id)
        XCTAssertTrue(queue.isWaitingToAppend(added.id))
        XCTAssertTrue(queue.hasUnfinishedAppend(to: target.id))
        XCTAssertEqual(try stored(added.id)?.draftText, "補的。")
        XCTAssertEqual(try stored(target.id)?.draftText, "第一段。\n\n第二段。")

        isTyping = false
        queue.mergeWaiting(into: target.id)
        XCTAssertEqual(try stored(target.id)?.draftText, "第一段。\n\n第二段。\n\n補的。")
        XCTAssertNil(try stored(added.id))
        XCTAssertFalse(queue.isWaitingToAppend(added.id))
    }

    func test等的時候離開那頁_改成直接接進存檔() throws {
        let queue = makeQueue(at: nil)
        let token = UUID()
        queue.openEditor(.init(token: token) { _, _ in .busy }, for: target.id)
        XCTAssertEqual(queue.mergeIntoAppendTarget(added).id, added.id)
        queue.closeEditor(token: UUID(), for: target.id)
        XCTAssertTrue(queue.isEditorOpen(token: token, for: target.id), "不是自己登記的不准取消")
        queue.closeEditor(token: token, for: target.id)
        queue.mergeWaiting(into: target.id)
        XCTAssertEqual(try stored(target.id)?.draftText, "第一段。\n\n第二段。\n\n補的。")
        XCTAssertNil(try stored(added.id))
    }

    func test接不上_原篇正在整理或不見了_留成獨立一篇() throws {
        let busy = makeQueue(at: nil)
        busy.inFlight.insert(target.id.uuidString)
        XCTAssertEqual(busy.mergeIntoAppendTarget(added).id, added.id)
        XCTAssertFalse(busy.hasUnfinishedAppend(to: target.id))

        let gone = makeQueue(at: nil)
        try store.delete(id: target.id)
        XCTAssertEqual(gone.mergeIntoAppendTarget(added).id, added.id)
        XCTAssertEqual(try stored(added.id)?.draftText, "補的。")
    }

    // MARK: 標題欄

    func test標題按下一步跳到正文_貼進來的好幾行接成一行() {
        let typed = TranscriptDetailView.titleAfterReturn(from: "標題", to: "標題\n")
        XCTAssertEqual(typed.text, "標題")
        XCTAssertTrue(typed.moves)
        let middle = TranscriptDetailView.titleAfterReturn(from: "標題", to: "標\n題")
        XCTAssertEqual(middle.text, "標題")
        XCTAssertTrue(middle.moves)
        let pasted = TranscriptDetailView.titleAfterReturn(from: "", to: "甲\n乙")
        XCTAssertEqual(pasted.text, "甲 乙")
        XCTAssertFalse(pasted.moves)
        XCTAssertNil(TranscriptDetailView.cleanedTitle("  \n"))
        XCTAssertEqual(TranscriptDetailView.cleanedTitle(" 標題 "), "標題")
    }

    // MARK: 幫手

    private func makeQueue(at insertion: InsertionPoint?) -> TranscriptionQueue {
        let queue = TranscriptionQueue()
        queue.appendTargetsByTranscript[added.id] = TranscriptionQueue.AppendTarget(
            transcriptID: target.id,
            insertion: insertion
        )
        return queue
    }

    private func stored(_ id: UUID) throws -> Transcript? {
        try store.loadAll().transcripts.first { $0.id == id }
    }
}
