@testable import MiSay
import XCTest

/// W5 鍵盤上方的標題、粗體、清單：加記號、再按拿掉、游標跟著字走、選好幾行一起加。
final class MarkdownFormattingTests: XCTestCase {
    private typealias Format = MarkdownFormatting

    func test標題加在游標那一行_游標往後推_再按拿掉() {
        let added = Format.toggle(
            .heading,
            in: "第一行\n第二行",
            selection: 6 ..< 6
        )
        XCTAssertEqual(added, Format.Edit(text: "第一行\n## 第二行", selection: 9 ..< 9))

        let removed = Format.toggle(
            .heading,
            in: added.text,
            selection: added.selection
        )
        XCTAssertEqual(removed, Format.Edit(text: "第一行\n第二行", selection: 6 ..< 6))
    }

    func test清單選好幾行一起加_已經有的不重複加() {
        let edit = Format.toggle(
            .list, in: "甲\n- 乙\n丙", selection: 0 ..< 7
        )
        XCTAssertEqual(edit.text, "- 甲\n- 乙\n- 丙")

        // 全部都有了才拿掉。
        let removed = Format.toggle(
            .list,
            in: edit.text,
            selection: 0 ..< edit.text.count
        )
        XCTAssertEqual(removed.text, "甲\n乙\n丙")
    }

    func test選取停在下一行開頭_那行不算() {
        let edit = Format.toggle(
            .list, in: "甲\n乙", selection: 0 ..< 2
        )
        XCTAssertEqual(edit.text, "- 甲\n乙")
    }

    func test游標在要拿掉的記號中間_停在那行開頭() {
        let edit = Format.toggle(
            .heading, in: "## 標題", selection: 1 ..< 1
        )
        XCTAssertEqual(edit, Format.Edit(text: "標題", selection: 0 ..< 0))
    }

    func test粗體包住選的字_再按拿掉_沒選字游標停在中間() {
        let bold = Format.toggleBold(in: "我覺得很重要", selection: 3 ..< 6)
        XCTAssertEqual(bold, Format.Edit(text: "我覺得**很重要**", selection: 5 ..< 8))

        let plain = Format.toggleBold(in: bold.text, selection: bold.selection)
        XCTAssertEqual(plain, Format.Edit(text: "我覺得很重要", selection: 3 ..< 6))

        XCTAssertEqual(
            Format.toggleBold(in: "前後", selection: 1 ..< 1),
            Format.Edit(text: "前****後", selection: 3 ..< 3)
        )
    }

    func test選取超出字的範圍夾回來不越界() {
        let edit = Format.toggleBold(in: "短", selection: 5 ..< 9)
        XCTAssertEqual(edit, Format.Edit(text: "短****", selection: 3 ..< 3))
    }

    // MARK: 2026-11-24 小標、編號、引言、連結

    func test標題與小標互換_不疊記號_游標跟著走() {
        let sub = Format.toggle(.subheading, in: "## 標題", selection: 4 ..< 4)
        XCTAssertEqual(sub, Format.Edit(text: "### 標題", selection: 5 ..< 5))
        XCTAssertEqual(
            Format.toggle(.heading, in: sub.text, selection: sub.selection).text,
            "## 標題"
        )
        XCTAssertEqual(Format.toggle(.heading, in: "# 大標", selection: 0 ..< 0).text, "## 大標")
        XCTAssertEqual(Format.toggle(.list, in: "## 標題", selection: 3 ..< 3).text, "- 標題")
    }

    func test編號照順序_空行不加_再按拿掉() {
        let numbered = Format.toggle(.numbered, in: "甲\n\n- 乙\n丙", selection: 0 ..< 8)
        XCTAssertEqual(numbered.text, "1. 甲\n\n2. 乙\n3. 丙")
        let all = 0 ..< numbered.text.count
        XCTAssertEqual(
            Format.toggle(.numbered, in: numbered.text, selection: all).text,
            "甲\n\n乙\n丙"
        )
        XCTAssertEqual(
            Format.toggle(.numbered, in: "2026. 年", selection: 0 ..< 0).text,
            "1. 2026. 年"
        )
    }

    func test引言加上拿掉_空的一行也加得上() {
        XCTAssertEqual(Format.toggle(.quote, in: "他說", selection: 1 ..< 1).text, "> 他說")
        XCTAssertEqual(Format.toggle(.quote, in: "> 他說", selection: 3 ..< 3).text, "他說")
        XCTAssertEqual(
            Format.toggle(.list, in: "", selection: 0 ..< 0),
            Format.Edit(text: "- ", selection: 2 ..< 2)
        )
    }

    func test連結包住選的字_沒選字放網址_跨行放後面() {
        let url = "https://domyweb.org"
        XCTAssertEqual(
            Format.addLink(url, in: "看這裡喔", selection: 1 ..< 3),
            Format.Edit(text: "看[這裡](https://domyweb.org)喔", selection: 26 ..< 26)
        )
        XCTAssertEqual(Format.addLink(url, in: "看", selection: 1 ..< 1).text, "看" + url)
        XCTAssertEqual(Format.addLink(url, in: "甲\n乙", selection: 0 ..< 3).text, "甲\n乙" + url)
    }

    func test網址只收http與https_沒寫開頭補https() {
        XCTAssertEqual(Format.linkURL(from: " domyweb.org/a "), "https://domyweb.org/a")
        XCTAssertEqual(Format.linkURL(from: "https://a.tw/(x)"), "https://a.tw/%28x%29")
        XCTAssertNil(Format.linkURL(from: "javascript:alert.x"))
        XCTAssertNil(Format.linkURL(from: "ftp://a.tw"))
        XCTAssertNil(Format.linkURL(from: "不是網址"))
        XCTAssertNil(Format.linkURL(from: "https://"))
        XCTAssertNil(Format.linkURL(from: "a.tw b.tw"))
    }

    func test等的時候字變了_連結照前後文找回原處() {
        let request = LinkSheet.Request(selection: 1 ..< 3, text: "看這裡喔")
        let edit = request.adding("https://a.tw", to: "新的一段。看這裡喔")
        XCTAssertEqual(edit?.text, "新的一段。看[這裡](https://a.tw)喔")
        XCTAssertNil(request.adding("https://a.tw", to: "整篇換掉"))
    }
}
