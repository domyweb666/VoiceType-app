@testable import MiSay
import XCTest

/// 「請 AI 看整篇」R-C：唯讀稿子怎麼切段、哪幾個字塗金、編號放哪、要捲到哪一段。
/// 塗得好不好看只有米在手機上看得出來，這裡只驗位置對不對。
final class ReviewMarksTests: XCTestCase {
    private typealias Mark = ReviewMarks.Mark

    func test照換行切段_空行不回傳但位置照算() {
        let paragraphs = ReviewMarks.paragraphs(of: "一二\n\n三四五\n", marks: [])
        XCTAssertEqual(paragraphs.map(\.id), [0, 2])
        XCTAssertEqual(paragraphs.map(\.range), [0 ..< 2, 4 ..< 7])
        XCTAssertEqual(
            paragraphs.map(\.segments),
            [[.text("一二", .plain)], [.text("三四五", .plain)]]
        )
        XCTAssertEqual(ReviewMarks.paragraphs(of: "", marks: []), [])
    }

    func test卡點塗色_編號放在句子前面_正在講的那處另外塗() {
        let marks = [
            Mark(number: 1, range: 0 ..< 2, isCurrent: false),
            Mark(number: 2, range: 3 ..< 5, isCurrent: true),
        ]
        let paragraphs = ReviewMarks.paragraphs(of: "甲乙丙丁戊己", marks: marks)
        XCTAssertEqual(paragraphs.first?.segments, [
            .badge(1, isCurrent: false),
            .text("甲乙", .marked),
            .text("丙", .plain),
            .badge(2, isCurrent: true),
            .text("丁戊", .current),
            .text("己", .plain),
        ])
    }

    func test兩處疊在一起_疊到的字算正在講的_編號照順序() {
        let marks = [
            Mark(number: 2, range: 0 ..< 3, isCurrent: true),
            Mark(number: 1, range: 0 ..< 2, isCurrent: false),
        ]
        let paragraphs = ReviewMarks.paragraphs(of: "甲乙丙丁", marks: marks)
        XCTAssertEqual(paragraphs.first?.segments, [
            .badge(1, isCurrent: false),
            .badge(2, isCurrent: true),
            .text("甲乙", .current),
            .text("丙", .current),
            .text("丁", .plain),
        ])
    }

    func test第二段的卡點_位置跟引文找位置用同一套字數() throws {
        let text = "前面👨‍👩‍👧一段\n卡住的那句"
        let range = try XCTUnwrap(ReviewResult.range(of: "卡住的", in: text))
        let mark = Mark(number: 1, range: range, isCurrent: true)
        let paragraphs = ReviewMarks.paragraphs(of: text, marks: [mark])
        XCTAssertEqual(paragraphs.map(\.range), [0 ..< 5, 6 ..< 11])
        XCTAssertEqual(paragraphs.last?.segments, [
            .badge(1, isCurrent: true),
            .text("卡住的", .current),
            .text("那句", .plain),
        ])
    }

    func test捲到含那個字的段_落在空行就往後找() {
        let paragraphs = ReviewMarks.paragraphs(of: "一二\n\n三四", marks: [])
        XCTAssertEqual(ReviewMarks.paragraphID(containing: 1, in: paragraphs), 0)
        XCTAssertEqual(ReviewMarks.paragraphID(containing: 3, in: paragraphs), 2)
        XCTAssertEqual(ReviewMarks.paragraphID(containing: 5, in: paragraphs), 2)
        XCTAssertNil(ReviewMarks.paragraphID(containing: 9, in: paragraphs))
    }
}
