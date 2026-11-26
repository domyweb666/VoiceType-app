@testable import MiSay
import XCTest

/// 性能檢查 H1 第 2 步：兩萬字以內照舊整篇比、結果不變；更長的分段比也比得出來，整段刪掉加上標得對。
/// 句子都是自編的。
final class ChunkedDifferenceTests: XCTestCase {
    private let dropped = "這一段在口語稿裡有整理時被拿掉"
    private let added = "這一段是整理時自己加上的話"

    // MARK: 短稿不變

    func test兩萬字以內跟原本整篇比的結果一模一樣() {
        let pairs = [
            ("呃我想說那個", "我想說那個。"),
            ("第一句 第二句", "第一句\n第二句"),
            ("所以我就所以我就先關掉", "所以我就先把它關掉。"),
            ("", "只有文字稿"),
            ("只有口語稿", ""),
            (spoken(1 ... 300), written(1 ... 300)),
        ]
        for (raw, polished) in pairs {
            let old = Array(raw)
            let new = Array(polished)
            XCTAssertLessThanOrEqual(old.count + new.count, ChunkedDifference.maxDirectUnits)
            let chunked = ChunkedDifference.changedOffsets(from: old, to: new)
            let original = directOffsets(from: old, to: new)
            XCTAssertEqual(chunked.removed, original.removed)
            XCTAssertEqual(chunked.inserted, original.inserted)
        }
    }

    // MARK: 長稿

    func test五萬字的長稿比得出來_刪掉的發聲詞一個不漏() {
        let raw = spoken(1 ... 950)
        let polished = written(1 ... 950)
        XCTAssertGreaterThan(raw.count + polished.count, 50000)
        XCTAssertFalse(PolishDiff.isTooLong(raw: raw, polished: polished))

        // CI 的機器慢，只擋「比到卡住」，不量快慢。
        let start = Date()
        let diff = PolishDiff(from: raw, to: polished)
        XCTAssertLessThan(Date().timeIntervalSince(start), 60)

        assertCovers(diff, raw: raw, polished: polished)
        XCTAssertEqual(diff.removedCount, 950)
        XCTAssertEqual(diff.addedCount, 0)
        XCTAssertEqual(Set(diff.runs.filter { $0.kind == .removed }.map(\.text)), ["呃"])
    }

    func test長稿整段刪掉和整段加上都標得出來() {
        var rawParagraphs = paragraphs(1 ... 950, filler: "")
        var polishedParagraphs = rawParagraphs
        rawParagraphs.insert(dropped, at: 40)
        polishedParagraphs.insert(added, at: 150)
        let raw = rawParagraphs.joined(separator: "\n\n")
        let polished = polishedParagraphs.joined(separator: "\n\n")
        XCTAssertGreaterThan(raw.count + polished.count, ChunkedDifference.maxDirectUnits)

        let diff = PolishDiff(from: raw, to: polished)

        assertCovers(diff, raw: raw, polished: polished)
        XCTAssertEqual(diff.runs.filter { $0.kind == .removed }.map(\.text), [dropped])
        XCTAssertEqual(diff.runs.filter { $0.kind == .added }.map(\.text), [added])
        XCTAssertEqual(diff.removedCount, dropped.count)
        XCTAssertEqual(diff.addedCount, added.count)
    }

    func test長稿對字也照順序對_每個對到的字都一樣() {
        let old = Array(spoken(1 ... 950))
        let new = Array(written(1 ... 950).filter { !$0.isWhitespace })

        let alignment = MeaningAlignment(from: old, to: new)

        XCTAssertEqual(alignment.matches.count, old.count)
        XCTAssertEqual(alignment.matches.filter { $0 == nil }.count, 950)
        let matched = alignment.matches.enumerated().compactMap { oldIndex, match in
            match.map { (oldIndex: oldIndex, newIndex: $0) }
        }
        XCTAssertEqual(matched.count, new.count)
        XCTAssertTrue(matched.allSatisfy { old[$0.oldIndex] == new[$0.newIndex] })
        XCTAssertEqual(matched.map(\.newIndex), Array(new.indices))
    }

    func test長稿整篇換掉找不到錨點_整篇當刪掉加上() {
        let raw = String(repeating: "甲", count: 12000)
        let polished = String(repeating: "乙", count: 12000)

        let diff = PolishDiff(from: raw, to: polished)

        XCTAssertEqual(diff.runs, [
            PolishDiff.Run(kind: .removed, text: raw),
            PolishDiff.Run(kind: .added, text: polished),
        ])
        XCTAssertEqual(diff.removedCount, 12000)
        XCTAssertEqual(diff.addedCount, 12000)
    }

    // MARK: 工具

    /// 口語稿：整篇沒換行，每句都多一個「呃」。
    private func spoken(_ numbers: ClosedRange<Int>) -> String {
        numbers.map { sentence($0, filler: "呃") }.joined()
    }

    /// 文字稿：拿掉「呃」，五句一段。
    private func written(_ numbers: ClosedRange<Int>) -> String {
        paragraphs(numbers, filler: "").joined(separator: "\n\n")
    }

    private func paragraphs(_ numbers: ClosedRange<Int>, filler: String) -> [String] {
        let sentences = numbers.map { sentence($0, filler: filler) }
        return stride(from: 0, to: sentences.count, by: 5).map { start in
            sentences[start ..< min(start + 5, sentences.count)].joined()
        }
    }

    private func sentence(_ number: Int, filler: String) -> String {
        "第\(number)件事，\(filler)我想說那個其實很重要，所以要先講清楚。"
    }

    /// 改之前的比法，對照用。
    private func directOffsets(
        from old: [Character],
        to new: [Character]
    ) -> (removed: Set<Int>, inserted: Set<Int>) {
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in new.difference(from: old) {
            switch change {
            case let .remove(offset, _, _):
                removed.insert(offset)
            case let .insert(offset, _, _):
                inserted.insert(offset)
            }
        }
        return (removed, inserted)
    }

    /// 刪掉的以外合起來是文字稿；加上的以外（空白不算）合起來是口語稿。
    private func assertCovers(
        _ diff: PolishDiff,
        raw: String,
        polished: String,
        line: UInt = #line
    ) {
        let shown = diff.runs.filter { $0.kind != .removed }.map(\.text).joined()
        XCTAssertEqual(shown, polished, line: line)
        let said = diff.runs.filter { $0.kind != .added }.map(\.text).joined()
        XCTAssertEqual(
            said.filter { !$0.isWhitespace },
            raw.filter { !$0.isWhitespace },
            line: line
        )
    }
}
