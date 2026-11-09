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
}
