@testable import MiSay
import XCTest

/// W5 鍵盤上方的標題、粗體、清單：加記號、再按拿掉、游標跟著字走、選好幾行一起加。
final class MarkdownFormattingTests: XCTestCase {
    private typealias Format = MarkdownFormatting

    func test標題加在游標那一行_游標往後推_再按拿掉() {
        let added = Format.toggleLinePrefix(
            Format.headingPrefix,
            in: "第一行\n第二行",
            selection: 6 ..< 6
        )
        XCTAssertEqual(added, Format.Edit(text: "第一行\n## 第二行", selection: 9 ..< 9))

        let removed = Format.toggleLinePrefix(
            Format.headingPrefix,
            in: added.text,
            selection: added.selection
        )
        XCTAssertEqual(removed, Format.Edit(text: "第一行\n第二行", selection: 6 ..< 6))
    }

    func test清單選好幾行一起加_已經有的不重複加() {
        let edit = Format.toggleLinePrefix(Format.listPrefix, in: "甲\n- 乙\n丙", selection: 0 ..< 7)
        XCTAssertEqual(edit.text, "- 甲\n- 乙\n- 丙")

        // 全部都有了才拿掉。
        let removed = Format.toggleLinePrefix(
            Format.listPrefix,
            in: edit.text,
            selection: 0 ..< edit.text.count
        )
        XCTAssertEqual(removed.text, "甲\n乙\n丙")
    }

    func test選取停在下一行開頭_那行不算() {
        let edit = Format.toggleLinePrefix(Format.listPrefix, in: "甲\n乙", selection: 0 ..< 2)
        XCTAssertEqual(edit.text, "- 甲\n乙")
    }

    func test游標在要拿掉的記號中間_停在那行開頭() {
        let edit = Format.toggleLinePrefix(Format.headingPrefix, in: "## 標題", selection: 1 ..< 1)
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
}
