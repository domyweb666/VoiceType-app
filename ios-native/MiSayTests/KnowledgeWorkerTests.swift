@testable import MiSay
import XCTest

/// 組塊 K 的純函式：Markdown 檔名與內容（K2）、接著錄怎麼接（K3）。
final class KnowledgeWorkerTests: XCTestCase {
    func testMarkdown檔名放日期與開頭幾個字而且不含不能用的字元() {
        let parts = DateComponents(year: 2026, month: 11, day: 9, hour: 14, minute: 30)
        let created = Calendar.current.date(from: parts)
        let transcript = Transcript(
            createdAt: created ?? Date(),
            durationSeconds: 3660,
            rawText: "口語稿",
            draftText: "今天想講訂閱制/定價這件事，先從成本算起。"
        )
        let name = MarkdownExport.fileName(for: transcript)
        XCTAssertEqual(name, "2026-11-09 1430 今天想講訂閱制 定價這件.md")
        let content = MarkdownExport.content(for: transcript)
        let header = ["---", "date: 2026-11-09 14:30", "length: 61 分鐘", "source: 米說", "---", "", ""]
            .joined(separator: "\n")
        XCTAssertTrue(content.hasPrefix(header))
        XCTAssertTrue(content.hasSuffix("先從成本算起。\n"))
    }

    func test接著錄接在後面原本的字不動() {
        var first = Transcript(
            durationSeconds: 600,
            rawText: "第一段口語",
            draftText: "第一段改過",
            originalDraft: "第一段原稿"
        )
        let second = Transcript(durationSeconds: 300, rawText: "第二段口語", draftText: "第二段草稿")
        first.append(second)
        XCTAssertEqual(first.rawText, "第一段口語\n\n第二段口語")
        XCTAssertEqual(first.draftText, "第一段改過\n\n第二段草稿")
        XCTAssertEqual(first.originalDraft, "第一段原稿\n\n第二段草稿")
        XCTAssertEqual(first.durationSeconds, 900)
        XCTAssertEqual(first.isCombined, true)
        XCTAssertEqual(first.unlearnedEdit?.to, "第一段改過\n\n第二段草稿", "接上去的那段不算修改，只有原本改過的那段算")
    }

    func test聽原音段落照字數比例估時間() {
        let draft = ["一二三四", "", "五六七八九"].joined(separator: "\n")
        let transcript = Transcript(durationSeconds: 100, rawText: "口語", draftText: draft)
        let paragraphs = OriginalAudioSheet.paragraphs(of: transcript)
        XCTAssertEqual(paragraphs.map(\.preview), ["一二三四", "五六七八九"])
        XCTAssertEqual(paragraphs.first?.time, 0)
        // 第二段前面有「一二三四」加兩個換行共 6 個字，全部 11 個字。
        XCTAssertEqual(paragraphs.last?.time ?? 0, 600.0 / 11.0, accuracy: 0.001)
    }

    func test一直留著的錄音只有那篇刪了才刪() {
        let now = Date()
        let old = Transcript(
            durationSeconds: 60,
            rawText: "口語",
            draftText: "文字",
            polishedAt: now.addingTimeInterval(-30 * 24 * 60 * 60)
        )
        let orphan = UUID()
        let doomed = RetainedRecordings.idsToDelete(
            retainedIDs: [old.id, orphan],
            transcripts: [old],
            deletesOrphans: true,
            keepsForever: true,
            now: now,
            availableBytes: 10
        )
        XCTAssertEqual(doomed, [orphan])
    }

    func test重點存在錄音旁邊接著錄時秒數往後接() throws {
        let name = "marks-\(UUID().uuidString).wav"
        let marks = RecordingMarks()
        try marks.add(90, forRecordingNamed: name)
        try marks.add(30, forRecordingNamed: name)
        let url = try PendingRecordings().directoryURL().appending(path: name)
        XCTAssertEqual(marks.load(forRecordingAt: url), [30, 90])
        marks.delete(forRecordingAt: url)
        XCTAssertEqual(marks.load(forRecordingAt: url), [])

        var first = Transcript(durationSeconds: 600, rawText: "甲")
        var second = Transcript(durationSeconds: 300, rawText: "乙")
        second.marks = [10]
        first.append(second)
        XCTAssertEqual(first.marks, [610])
    }
}
