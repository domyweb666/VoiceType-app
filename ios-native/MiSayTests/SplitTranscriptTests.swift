@testable import MiSay
import XCTest

/// 片 J3 拆篇存成的那一篇：欄位、改寫那張頁不算它、勾選與存過的狀態、畫面上講的字。
final class SplitTranscriptTests: XCTestCase {
    private let source = SplitTranscriptTests.makeSource()

    func test存成的那篇_字與原稿一樣_記得原篇_沒有錄音沒有模型() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 60)
        let piece = Transcript.split(from: source, id: id, title: "散步", text: "走了一圈。", now: now)
        XCTAssertEqual(piece.id, id)
        XCTAssertEqual(piece.createdAt, now)
        XCTAssertEqual(piece.updatedAt, now)
        XCTAssertEqual(piece.title, "散步")
        XCTAssertEqual(piece.rawText, "")
        XCTAssertEqual(piece.durationSeconds, 0)
        XCTAssertEqual(piece.draftText, "走了一圈。")
        XCTAssertEqual(piece.originalDraft, "走了一圈。")
        XCTAssertEqual(piece.learnedDraft, "走了一圈。")
        XCTAssertNil(piece.polishModel)
        XCTAssertEqual(piece.tags, ["課程"])
        XCTAssertEqual(piece.sourceID, source.id)
        XCTAssertEqual(piece.sourceKind, "split")
        XCTAssertTrue(piece.isSplit)
        XCTAssertTrue(piece.isDerived)
        XCTAssertFalse(piece.isWritten)
        XCTAssertNil(piece.unlearnedEdit)
    }

    func test改寫清單不含拆篇_兩種都還算從這篇來的() {
        let piece = makePiece()
        let rewrite = TranscriptRewrite(kind: "threads", text: "串文", model: "m")
        let rewritten = Transcript.derived(from: source, rewrite: rewrite)
        XCTAssertFalse(rewritten.isSplit)

        var pages = TranscriptDetailView.DerivedPages()
        pages.refresh(sourceID: source.id, from: [source, piece, rewritten])
        XCTAssertEqual(pages.rewritten.map(\.id), [rewritten.id])
        XCTAssertEqual(pages.pieces.map(\.id), [piece.id])
        XCTAssertEqual(pages.transcripts.count, 2)
    }

    func test統計不算拆出來的() {
        XCTAssertEqual(
            DictationStats(transcripts: [source, makePiece()]),
            DictationStats(transcripts: [source])
        )
    }

    func test拆出來的不寫成改寫() {
        XCTAssertEqual(TranscriptListView.lengthNote(for: makePiece()), "從別篇拆出來的")
        XCTAssertEqual(
            TranscriptDetailView.derivedNote(kind: Transcript.splitKind, model: nil),
            "從別篇拆出來的"
        )
        XCTAssertNil(RewriteKind(rawValue: Transcript.splitKind), "不能跟改寫的種類撞名")
    }

    func test先全部勾起來_存過的不再算_只有一件事沒有東西要存() {
        let topics = [makeTopic("甲"), makeTopic("乙"), makeTopic("丙")]
        var session = SplitSheet.Session()
        XCTAssertTrue(session.unsavedTopics.isEmpty)
        session.show(
            TopicSplit(topics: topics, unassignedParagraphs: 0),
            from: "原稿",
            hasEarlierPieces: false
        )
        XCTAssertEqual(session.chosenTopics, topics)

        session.toggle(topics[0].id)
        XCTAssertEqual(session.chosenTopics, [topics[1], topics[2]])
        session.savedIDs.insert(topics[1].id)
        XCTAssertEqual(session.chosenTopics, [topics[2]], "再按只存剩下的")
        XCTAssertEqual(session.unsavedTopics, [topics[0], topics[2]])
        session.toggle(topics[0].id)
        XCTAssertEqual(session.chosenTopics, [topics[0], topics[2]])

        session.show(
            TopicSplit(topics: [topics[0]], unassignedParagraphs: 0),
            from: "原稿",
            hasEarlierPieces: false
        )
        XCTAssertTrue(session.savedIDs.isEmpty)
        XCTAssertTrue(session.unsavedTopics.isEmpty)
    }

    func test以前拆過就先都不勾() {
        let topics = [makeTopic("甲"), makeTopic("乙")]
        var session = SplitSheet.Session()
        session.show(
            TopicSplit(topics: topics, unassignedParagraphs: 0),
            from: "原稿",
            hasEarlierPieces: true
        )
        XCTAssertTrue(session.chosenTopics.isEmpty)
        XCTAssertEqual(session.unsavedTopics, topics)
        session.toggle(topics[1].id)
        XCTAssertEqual(session.chosenTopics, [topics[1]])
        XCTAssertEqual(SplitSheet.earlierNote(count: 3), "以前拆過 3 篇，存之前看看有沒有重複。")
    }

    func test只分出一件又有段落沒歸到_不說是同一件事() {
        let whole = TopicSplit(topics: [makeTopic("甲")], unassignedParagraphs: 0)
        XCTAssertEqual(SplitSheet.singleTopicNote(whole), "這趟講的是同一件事，不用拆。")
        XCTAssertEqual(SplitSheet.resultHeader(whole), "講了 1 件事")

        let partial = TopicSplit(topics: [makeTopic("甲")], unassignedParagraphs: 4)
        XCTAssertEqual(
            SplitSheet.singleTopicNote(partial),
            "只分出一件事，還有 4 段沒歸到。按上面的「重新分一次」再試試。"
        )
        XCTAssertEqual(SplitSheet.resultHeader(partial), "沒分好")

        let topics = [makeTopic("甲"), makeTopic("乙")]
        XCTAssertFalse(TopicSplit(topics: topics, unassignedParagraphs: 4).isIncomplete)
    }

    func test畫面上講的字() {
        XCTAssertEqual(
            SplitSheet.Session.unsavedNote(count: 2),
            "有 2 篇沒存成，手機空間可能不夠。再按一次只會存剩下的。"
        )
        XCTAssertTrue(SplitSheet.costNote.hasSuffix("離開這篇，分好的結果不會留。"))
        XCTAssertEqual(SplitSheet.paragraphNote([1]), "第 1 段")
        XCTAssertEqual(SplitSheet.paragraphNote([1, 3, 4, 5, 9, 10]), "第 1、3～5、9～10 段")
        XCTAssertEqual(SplitSheet.saveButtonTitle(count: 3), "存成 3 篇")
        XCTAssertEqual(SplitSheet.saveButtonTitle(count: 0), "勾要存的")
        XCTAssertEqual(SplitSheet.unassignedNote(count: 2), "有 2 段沒有歸到哪一件事，字都還在這篇裡。")
    }

    private func makePiece() -> Transcript {
        Transcript.split(from: source, id: UUID(), title: "散步", text: "走了一圈。")
    }

    private func makeTopic(_ title: String) -> SplitTopic {
        SplitTopic(title: title, summary: "摘要", text: "字", paragraphs: [1])
    }

    private static func makeSource() -> Transcript {
        var source = Transcript(durationSeconds: 60, rawText: "口語", draftText: "文字稿")
        source.title = "原篇標題"
        source.tags = ["課程"]
        return source
    }
}
