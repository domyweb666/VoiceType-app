@testable import MiSay
import XCTest

/// 組塊 Y5：改寫好的存成自己的一篇。欄位、標題怎麼拆、哪些地方不把它當自己打的、畫面上講的字。
final class DerivedTranscriptTests: XCTestCase {
    private let source = DerivedTranscriptTests.makeSource()

    func test改寫存成新的一篇_三份文字稿一樣_記得原篇與補充要求() {
        let rewrite = makeRewrite("1/ 甲\n2/ 乙", instruction: "用大白話")
        let derived = Transcript.derived(from: source, rewrite: rewrite)

        XCTAssertEqual(derived.id, rewrite.id, "再按一次拿來編輯要認得是同一篇")
        XCTAssertEqual(derived.createdAt, rewrite.createdAt)
        XCTAssertEqual(derived.rawText, "")
        XCTAssertEqual(derived.durationSeconds, 0)
        XCTAssertEqual(derived.draftText, "1/ 甲\n2/ 乙")
        XCTAssertEqual(derived.originalDraft, derived.draftText)
        XCTAssertEqual(derived.learnedDraft, derived.draftText)
        XCTAssertEqual(derived.polishModel, "m")
        XCTAssertEqual(derived.sourceID, source.id)
        XCTAssertEqual(derived.sourceKind, "threads")
        XCTAssertEqual(derived.sourceInstruction, "用大白話")
        XCTAssertEqual(derived.tags, ["課程"])
        XCTAssertEqual(derived.title, "原篇標題", "結果沒有標題就沿用原篇的")
    }

    func test開頭是標題就拆出來_正文不重複() {
        let rewrite = makeRewrite("\n# 新標題\n\n第一段\n\n## 小標")
        let derived = Transcript.derived(from: source, rewrite: rewrite)
        XCTAssertEqual(derived.title, "新標題")
        XCTAssertEqual(derived.draftText, "第一段\n\n## 小標")
        XCTAssertEqual(Transcript.splitHeading(of: "# **新標題**\n內文").heading, "新標題")
    }

    func test不是標題的不拆_只有標題沒有內文也不拆() {
        for text in ["#標籤 開頭\n內文", "## 小標\n內文", "內文\n# 後面的標題", "# 只有標題", "#"] {
            let split = Transcript.splitHeading(of: text)
            XCTAssertNil(split.heading, text)
            XCTAssertEqual(split.body, text)
        }
        var untitled = source
        untitled.title = nil
        XCTAssertNil(Transcript.derived(from: untitled, rewrite: makeRewrite("內文")).title)
    }

    func test改寫來的不算自己打的_清空了也不會被丟_改了不學() {
        var derived = Transcript.derived(from: source, rewrite: makeRewrite("內文"))
        XCTAssertTrue(derived.isDerived)
        XCTAssertFalse(derived.isWritten)
        derived.draftText = ""
        XCTAssertFalse(derived.isBlankDraft)
        XCTAssertNil(derived.unlearnedEdit)
        XCTAssertFalse(source.isDerived)
    }

    func test統計不算改寫來的() {
        let derived = Transcript.derived(from: source, rewrite: makeRewrite("內文內文"))
        XCTAssertEqual(
            DictationStats(transcripts: [source, derived]),
            DictationStats(transcripts: [source])
        )
        XCTAssertNil(DictationStats.homeSummary(for: [derived]))
    }

    func test列出改寫好的_新的在前_垃圾桶與別篇的不算() {
        let older = makeRewrite("舊", createdAt: Date(timeIntervalSince1970: 0))
        let newer = makeRewrite("新", createdAt: Date(timeIntervalSince1970: 60))
        var trashed = Transcript.derived(from: source, rewrite: makeRewrite("丟掉的"))
        trashed.trashedAt = Date()
        let other = Transcript(durationSeconds: 1, rawText: "別篇")
        let stored = [
            Transcript.derived(from: source, rewrite: older),
            Transcript.derived(from: other, rewrite: makeRewrite("別篇的")),
            trashed,
            Transcript.derived(from: source, rewrite: newer),
            source,
        ]
        let found = Transcript.derived(of: source.id, in: stored)
        XCTAssertEqual(found.map(\.draftText), ["新", "舊"])

        var pages = TranscriptDetailView.DerivedPages()
        pages.refresh(sourceID: source.id, from: stored)
        pages.markDeleted(newer.id)
        XCTAssertEqual(pages.transcripts.map(\.id), [older.id])
        pages.refresh(sourceID: source.id, from: stored)
        XCTAssertEqual(pages.transcripts.map(\.id), [older.id], "存檔還沒刪，也不能又列出來")
        XCTAssertTrue(pages.isDeleted(newer.id))
    }

    func test補充要求存得進去_舊檔沒有也讀得出來() throws {
        let rewrite = makeRewrite("內文", instruction: "大白話")
        let derived = Transcript.derived(from: source, rewrite: rewrite)
        let data = try JSONEncoder().encode(derived)
        let decoded = try JSONDecoder().decode(Transcript.self, from: data)
        XCTAssertEqual(decoded.sourceInstruction, "大白話")
        let old = try JSONEncoder().encode(source)
        XCTAssertNil(try JSONDecoder().decode(Transcript.self, from: old).sourceInstruction)
    }

    func test畫面上講的字() {
        let note = TranscriptDetailView.derivedNote(kind: "threads", model: "m")
        XCTAssertEqual(note, "改寫：Threads 串文・m")
        XCTAssertEqual(TranscriptDetailView.derivedNote(kind: "article", model: nil), "改寫：知識文章")
        XCTAssertTrue(RewriteKind.isThreads(stored: "threads"))
        XCTAssertFalse(RewriteKind.isThreads(stored: nil))

        var derived = Transcript.derived(from: source, rewrite: makeRewrite("開頭\n第二行"))
        XCTAssertEqual(RewritesSheet.headline(for: derived), "原篇標題")
        derived.title = nil
        XCTAssertEqual(RewritesSheet.headline(for: derived), "開頭 第二行")
    }

    private static func makeSource() -> Transcript {
        var source = Transcript(durationSeconds: 60, rawText: "口語", draftText: "文字稿")
        source.title = "原篇標題"
        source.tags = ["課程"]
        return source
    }

    private func makeRewrite(
        _ text: String,
        instruction: String? = nil,
        createdAt: Date = Date()
    ) -> TranscriptRewrite {
        TranscriptRewrite(
            kind: RewriteKind.threads.rawValue,
            text: text,
            model: "m",
            createdAt: createdAt,
            instruction: instruction
        )
    }
}
