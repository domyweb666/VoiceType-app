@testable import MiSay
import UIKit
import UniformTypeIdentifiers
import XCTest

/// 組塊 Y1：複製出去是乾淨的。純文字、HTML、剪貼簿、檔名與檔頭。
final class CleanExportTests: XCTestCase {
    func test純文字去掉標題粗體斜體與行內碼的記號() {
        let markdown = "# 大標\n## 小標\n這是**重點**，*真的*。\n用 `git push` 推"
        let expected = "大標\n小標\n這是重點，真的。\n用 git push 推"
        XCTAssertEqual(PlainTextExport.text(from: markdown), expected)
        XCTAssertEqual(PlainTextExport.text(from: "***又粗又斜***"), "又粗又斜")
        XCTAssertEqual(PlainTextExport.text(from: "iPhone**15**很貴"), "iPhone15很貴")
    }

    func test純文字的清單與引用() {
        let markdown = "- 買**牛奶**\n  - 全脂\n* 星號\n1. 先做這個\n> 引用的話\n>\n> - 裡面的清單"
        let expected = "・買牛奶\n  ・全脂\n・星號\n1. 先做這個\n引用的話\n\n・裡面的清單"
        XCTAssertEqual(PlainTextExport.text(from: markdown), expected)
    }

    func test純文字的連結寫出網址() {
        XCTAssertEqual(
            PlainTextExport.text(from: "看**[官網](https://domyweb.org/a_(b))**吧"),
            "看官網（https://domyweb.org/a_(b)）吧"
        )
        XCTAssertEqual(
            PlainTextExport.text(from: "[https://a.tw](https://a.tw)"),
            "https://a.tw"
        )
    }

    func test看不出是記號的字一個都不動() {
        let untouched = [
            "C# 和 F#", "#標籤", "C#", "2*3", "2*3 和 4*5", "2**10 和 3**5", "a * b * c",
            "snake_case_name", "長*寬*高", "王*明", "5*、4*、3*", "標（*）的是必填，（*）",
            "密碼 ****", "只有一邊**沒關", "[註](見下)", "arr[0](x)", "-5 度", "3.14",
            "2026. 那年", ">3 個", "第一段\n\n第二段", "　　縮排的字",
        ]
        for text in untouched {
            XCTAssertEqual(PlainTextExport.text(from: text), text)
        }
    }

    func test清單_版本紀錄_垃圾桶的預覽看不到記號() {
        let markdown = "\n## 開頭\n這是**重點**\n- 買牛奶"
        XCTAssertEqual(PlainTextExport.opening(of: markdown), "開頭\n這是重點\n・買牛奶")
        XCTAssertEqual(VersionsSheet.preview(markdown), "開頭 這是重點 ・買牛奶")
        let transcript = Transcript(durationSeconds: 1, rawText: "口語", draftText: markdown)
        XCTAssertEqual(TrashView.rowText(for: transcript), "開頭\n這是重點\n・買牛奶")
        XCTAssertEqual(PlainTextExport.opening(of: "C# 和 2*3"), "C# 和 2*3")
        XCTAssertEqual(PlainTextExport.opening(of: " \n"), "")
    }

    func test預覽只拿開頭幾個字_切在粗體中間也看不到記號() {
        let long = String(repeating: "長", count: 15000)
        let expected = String(repeating: "長", count: VersionsSheet.previewLength)
        XCTAssertEqual(VersionsSheet.preview("## " + long), expected)
        XCTAssertEqual(VersionsSheet.preview("**" + long + "**"), expected)
        XCTAssertEqual(
            PlainTextExport.opening(of: long).count,
            PlainTextExport.openingLength
        )
    }

    func test三個以上連續換行縮成兩個() {
        XCTAssertEqual(PlainTextExport.text(from: "前\n\n\n\n後"), "前\n\n後")
        XCTAssertEqual(PlainTextExport.text(from: "前\n \n　\n  後"), "前\n\n  後")
        XCTAssertEqual(PlainTextExport.text(from: "前\r\n\r\n\r\n後"), "前\n\n後")
    }

    func testHTML的標題段落與粗體() {
        let markdown = "# 大標\n### 小標\n第一行**粗**\n第二行\n\n另一段*斜*"
        let expected = "<h2>大標</h2><h3>小標</h3><p>第一行<strong>粗</strong><br>第二行</p>"
            + "<p>另一段斜</p>"
        XCTAssertEqual(HTMLExport.html(from: markdown), expected)
    }

    func testHTML的清單可以縮排也會接著數() {
        XCTAssertEqual(
            HTMLExport.html(from: "- 甲\n  - 甲一\n- 乙\n\n1. 先\n2. 後"),
            "<ul><li>甲<ul><li>甲一</li></ul></li><li>乙</li></ul>"
                + "<ol><li>先</li><li>後</li></ol>"
        )
        XCTAssertEqual(
            HTMLExport.html(from: "1. 先\n說明\n2. 後"),
            "<ol><li>先</li></ol><p>說明</p><ol start=\"2\"><li>後</li></ol>"
        )
    }

    func testHTML的引用() {
        XCTAssertEqual(
            HTMLExport.html(from: "> 一\n> - 二\n\n後"),
            "<blockquote><p>一</p><ul><li>二</li></ul></blockquote><p>後</p>"
        )
    }

    func testHTML一律跳脫而且連結只准網頁() {
        XCTAssertEqual(
            HTMLExport.html(from: "<script>a & \"b\"</script>"),
            "<p>&lt;script&gt;a &amp; &quot;b&quot;&lt;/script&gt;</p>"
        )
        XCTAssertEqual(
            HTMLExport.html(from: "[官網](https://a.tw/?x=1&y=\"2)"),
            "<p><a href=\"https://a.tw/?x=1&amp;y=&quot;2\">官網</a></p>"
        )
        XCTAssertEqual(
            HTMLExport.html(from: "[壞](javascript:alert)"),
            "<p>壞（javascript:alert）</p>"
        )
    }

    func test剪貼簿同一個項目有純文字也有HTML() throws {
        let items = DraftPasteboard.items(for: "## 標\n**粗**")
        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item[UTType.utf8PlainText.identifier] as? String, "標\n粗")
        let data = try XCTUnwrap(item[UTType.html.identifier] as? Data)
        let html = try XCTUnwrap(String(bytes: data, encoding: .utf8))
        XCTAssertTrue(html.hasPrefix("<meta charset=\"utf-8\">"))
        XCTAssertTrue(html.hasSuffix("<h2>標</h2><p><strong>粗</strong></p>"))
    }

    /// 只認純文字的 App 走的就是 `string`。
    @MainActor
    func test只認純文字的地方拿得到乾淨的字() {
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        pasteboard.setItems(DraftPasteboard.items(for: "## 標\n**粗**"))
        XCTAssertEqual(pasteboard.string, "標\n粗")
    }

    func test有標題的檔名與檔頭用標題() {
        let parts = DateComponents(year: 2026, month: 11, day: 24, hour: 14, minute: 30)
        let created = Calendar.current.date(from: parts) ?? Date()
        var transcript = Transcript(
            createdAt: created,
            durationSeconds: 60,
            rawText: "口語稿",
            draftText: "正文"
        )
        XCTAssertEqual(MarkdownExport.fileName(for: transcript), "2026-11-24 1430 正文.md")
        XCTAssertFalse(MarkdownExport.content(for: transcript).contains("title:"))
        transcript.title = "  \n "
        XCTAssertNil(MarkdownExport.title(of: transcript))

        transcript.title = " 訂閱/定價：\"想清楚\" "
        XCTAssertEqual(
            MarkdownExport.fileName(for: transcript),
            "2026-11-24 1430 訂閱 定價： 想清楚.md"
        )
        let header = "---\ntitle: \"訂閱/定價：\\\"想清楚\\\"\"\ndate: 2026-11-24 14:30\n"
        XCTAssertTrue(MarkdownExport.content(for: transcript).hasPrefix(header))
        XCTAssertTrue(MarkdownExport.content(for: transcript).hasSuffix("---\n\n正文\n"))
        let fileName = TranscriptTextFile.fileName(for: transcript)
        XCTAssertTrue(fileName.hasSuffix(" 訂閱 定價： 想清楚.txt"))
    }

    func test存到資料夾那顆鈕寫得出資料夾名字() {
        XCTAssertEqual(ExportSheet.saveTitle(folderName: nil), "存成 Markdown…")
        XCTAssertEqual(ExportSheet.saveTitle(folderName: "筆記"), "存成 Markdown 到「筆記」")
    }
}
