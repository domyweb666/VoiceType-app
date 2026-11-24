@testable import MiSay
import XCTest

/// 組塊 Y1：串文拆成幾篇。
final class ThreadsPartsTests: XCTestCase {
    func test照編號拆而且編號留著() {
        let parts = ThreadsParts.split("1/ 第一篇\n還是第一篇\n\n2/\n第二篇\n\n3／第三篇")
        XCTAssertEqual(parts.map(\.number), [1, 2, 3])
        XCTAssertEqual(parts.map(\.text), ["1/ 第一篇\n還是第一篇", "2/\n第二篇", "3／第三篇"])
    }

    func test寫成幾分之幾與加粗也認得() {
        let parts = ThreadsParts.split("**1/2** 開頭\n2/3 的人這樣想\n**2/2** 結尾")
        XCTAssertEqual(parts.map(\.text), ["1/2 開頭\n2/3 的人這樣想", "2/2 結尾"])
    }

    func test內文裡的分數與日期不會拆() {
        let parts = ThreadsParts.split("1/ 開頭\n2/3 的人這樣想\n11/8 那天\n2/ 結尾")
        XCTAssertEqual(parts.map(\.text), ["1/ 開頭\n2/3 的人這樣想\n11/8 那天", "2/ 結尾"])
    }

    func test第一篇之前的話不會不見() {
        let parts = ThreadsParts.split("先講一句\n\n1/ 甲\n2/ 乙")
        XCTAssertEqual(parts.map(\.text), ["先講一句\n\n1/ 甲", "2/ 乙"])
    }

    func test沒有編號就整份一篇空的就沒有() {
        XCTAssertEqual(ThreadsParts.split("只有一段").map(\.text), ["只有一段"])
        XCTAssertEqual(ThreadsParts.split("1/ 只有一篇").map(\.text), ["1/ 只有一篇"])
        XCTAssertTrue(ThreadsParts.split(" \n ").isEmpty)
    }

    func test字數超過上限標得出來() {
        let exact = ThreadsParts.Part(number: 1, markdown: String(repeating: "字", count: 500))
        XCTAssertEqual(exact.overflow, 0)
        XCTAssertEqual(ThreadsPartsView.countText(for: exact), "500／500 字")
        let long = ThreadsParts.Part(number: 1, markdown: String(repeating: "字", count: 520))
        XCTAssertEqual(ThreadsPartsView.countText(for: long), "520／500 字，多了 20 字")
    }
}
