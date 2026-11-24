@testable import MiSay
import UIKit
import XCTest

/// 2026-11-17 新編輯框（試用）的 Markdown 樣子：標題、粗體有樣子，記號只在游標那一行露出來。
/// 只改樣子不改字，存下來還是同一份 Markdown。
final class MarkdownLineStyleTests: XCTestCase {
    private typealias Span = MarkdownLineStyle.Span

    func test標題_井字與空白是記號_後面是標題() {
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "## 小節"), [
            Span(kind: .headingMarker, range: NSRange(location: 0, length: 3)),
            Span(kind: .heading(level: 2), range: NSRange(location: 3, length: 2)),
        ])
    }

    func test井字後面沒空白不是標題_跟大綱同一條規則() {
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "#標籤不是標題"), [])
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "####### 七個太多"), [])
    }

    func test粗體_前後兩個星號是記號() {
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "這是**重點**喔"), [
            Span(kind: .boldMarker, range: NSRange(location: 2, length: 2)),
            Span(kind: .bold, range: NSRange(location: 4, length: 2)),
            Span(kind: .boldMarker, range: NSRange(location: 6, length: 2)),
        ])
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "只有一邊**沒關"), [])
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "空的****不算"), [])
    }

    func test清單記號() {
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "- 買牛奶"), [
            Span(kind: .listMarker, range: NSRange(location: 0, length: 2)),
        ])
    }

    func test小標_編號_引言() {
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "### 小標").last?.kind, .heading(level: 3))
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "12. 買牛奶"), [
            Span(kind: .listMarker, range: NSRange(location: 0, length: 4)),
        ])
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "> 他說"), [
            Span(kind: .quoteMarker, range: NSRange(location: 0, length: 2)),
            Span(kind: .quote, range: NSRange(location: 2, length: 2)),
        ])
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "3.14 是圓周率"), [])
        XCTAssertEqual(MarkdownLineStyle.spans(inLine: "2026. 年"), [])
    }

    func test游標碰到這一行_含行尾_才算在這一行() {
        let line = NSRange(location: 5, length: 4)
        func active(at caret: Int?) -> Bool {
            MarkdownLineStyle.isActive(
                line: line,
                selection: caret.map { NSRange(location: $0, length: 0) }
            )
        }
        XCTAssertTrue(active(at: 9))
        XCTAssertTrue(active(at: 5))
        XCTAssertFalse(active(at: 10))
        XCTAssertFalse(active(at: nil))
    }

    /// 游標在第一行：第一行的 `##` 看得到，第二行的 `**` 藏起來；字一個都沒少。
    func test套上去_游標那行露記號_別行藏記號_字不變() {
        let text = "## 標題\n這是**重點**"
        let storage = NSTextStorage(string: text)
        let base: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.black]
        MarkdownLineStyle.apply(
            to: storage,
            around: NSRange(location: 0, length: storage.length),
            selection: NSRange(location: 1, length: 0),
            base: base
        )
        XCTAssertEqual(storage.string, text)
        XCTAssertNotEqual(color(in: storage, at: 0), .clear)
        XCTAssertEqual(color(in: storage, at: 8), .clear)
        XCTAssertEqual(color(in: storage, at: 10), .black)
    }

    func test只重算碰到的那一行_別行不動() {
        let storage = NSTextStorage(string: "## 一\n## 二")
        let base: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.black]
        MarkdownLineStyle.apply(
            to: storage,
            around: NSRange(location: 6, length: 0),
            selection: nil,
            base: base
        )
        XCTAssertNil(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil))
        XCTAssertEqual(color(in: storage, at: 5), .clear)
    }

    private func color(in storage: NSTextStorage, at location: Int) -> UIColor? {
        storage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? UIColor
    }
}
