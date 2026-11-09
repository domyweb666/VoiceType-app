@testable import MiSay
import XCTest

/// W3「AI 改了什麼」：逐字比出沒動、刪掉、加上，空白換行當排版，刪幾字加幾字算得對。
final class PolishDiffTests: XCTestCase {
    func test刪掉的發聲詞和加上的標點分得出來() {
        let diff = PolishDiff(from: "呃我想說那個", to: "我想說那個。")

        XCTAssertEqual(diff.runs, [
            run(.removed, "呃"),
            run(.same, "我想說那個"),
            run(.added, "。"),
        ])
        XCTAssertEqual(diff.removedCount, 1)
        XCTAssertEqual(diff.addedCount, 1)
    }

    func test加上的換行照沒動顯示_刪掉的空白不顯示也不算() {
        let diff = PolishDiff(from: "第一句 第二句", to: "第一句\n第二句")

        XCTAssertEqual(diff.runs.map(\.kind), [.same])
        XCTAssertEqual(diff.runs.map(\.text).joined(), "第一句\n第二句")
        XCTAssertEqual(diff.removedCount, 0)
        XCTAssertEqual(diff.addedCount, 0)
    }

    func test沒改就整段沒動_合起來等於文字稿() {
        let same = PolishDiff(from: "一模一樣", to: "一模一樣")
        XCTAssertEqual(same.runs, [run(.same, "一模一樣")])
        XCTAssertEqual(RawTextSheet.summary(same), "AI 一個字都沒改。")

        let diff = PolishDiff(from: "所以我就所以我就先關掉", to: "所以我就先把它關掉。")
        let shown = diff.runs.filter { $0.kind != .removed }.map(\.text).joined()
        XCTAssertEqual(shown, "所以我就先把它關掉。")
        XCTAssertEqual(diff.removedCount, 4)
        XCTAssertEqual(diff.addedCount, 3)
    }

    func test太長的不比() {
        let half = String(repeating: "字", count: PolishDiff.maxCompareCharacters / 2)
        XCTAssertFalse(PolishDiff.isTooLong(raw: half, polished: half))
        XCTAssertTrue(PolishDiff.isTooLong(raw: half, polished: half + "多"))
    }

    func test比的是AI剛整理好的那份_舊的篇才用現在的文字稿() {
        var transcript = Transcript(durationSeconds: 10, rawText: "口語")
        transcript.applyPolish("AI 那份。", model: "m", style: .keepVoice)
        transcript.draftText = "我改過的。"
        XCTAssertEqual(
            RawTextSheet(transcript: transcript, startsWithDiff: true).polishedForCompare,
            "AI 那份。"
        )

        let old = Transcript(durationSeconds: 10, rawText: "口語", draftText: "舊的文字稿。")
        XCTAssertEqual(
            RawTextSheet(transcript: old, startsWithDiff: true).polishedForCompare,
            "舊的文字稿。"
        )
    }

    private func run(_ kind: PolishDiff.Kind, _ text: String) -> PolishDiff.Run {
        PolishDiff.Run(kind: kind, text: text)
    }
}
