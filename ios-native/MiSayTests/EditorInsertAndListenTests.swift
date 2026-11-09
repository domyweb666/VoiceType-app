@testable import MiSay
import XCTest

/// v0.2.7（2026-11-09 米的四點）：在游標處接著錄、編輯框邊打邊變樣、聽原音整段對字。
final class EditorInsertAndListenTests: XCTestCase {
    // MARK: 在游標處接著錄

    func test插入位置沒動_插在原處_前後各隔一個空行() {
        let text = "第一段。\n\n第二段。"
        let point = InsertionPoint(offset: 4, in: text)
        XCTAssertEqual(point.inserting("補的。", into: text), "第一段。\n\n補的。\n\n第二段。")
    }

    func test插入位置前面多了字_照前後文找到原處() {
        let original = "我現在進度有一點亂掉了。所以我需要固定一個時間點。"
        let point = InsertionPoint(offset: 12, in: original)
        let edited = "開頭加一句。" + original
        XCTAssertEqual(
            point.inserting("補的", into: edited),
            "開頭加一句。我現在進度有一點亂掉了。\n\n補的\n\n所以我需要固定一個時間點。"
        )
    }

    func test插入位置附近被改掉_回nil不猜() {
        let original = "我現在進度有一點亂掉了。所以我需要固定一個時間點。"
        let point = InsertionPoint(offset: 12, in: original)
        XCTAssertNil(point.resolvedOffset(in: "整篇都換掉了"))
    }

    func test前後文在別處出現兩次_不猜() {
        let point = InsertionPoint(offset: 2, in: "甲乙丙丁")
        XCTAssertNil(point.resolvedOffset(in: "前面甲乙丙丁，後面甲乙丙丁"))
    }

    func test插在中間_原稿也插在同一處_接上去的那段不算修改() {
        var target = Transcript(
            durationSeconds: 600,
            rawText: "口語一",
            draftText: "第一段。\n\n第二段。",
            originalDraft: "第一段。\n\n第二段。"
        )
        let added = Transcript(durationSeconds: 60, rawText: "口語補", draftText: "補的。")
        let point = InsertionPoint(offset: 4, in: target.draftText ?? "")
        XCTAssertTrue(target.insert(added, at: point))
        XCTAssertEqual(target.draftText, "第一段。\n\n補的。\n\n第二段。")
        XCTAssertEqual(target.originalDraft, "第一段。\n\n補的。\n\n第二段。")
        XCTAssertEqual(target.rawText, "口語一\n\n口語補", "口語稿照錄的順序接在後面")
        XCTAssertEqual(target.durationSeconds, 660)
        XCTAssertNotNil(target.combinedAt, "接過的篇不給播原音")
        XCTAssertNil(target.unlearnedEdit)
    }

    func test找不到位置_整段接在最後面_回false() {
        var target = Transcript(durationSeconds: 60, rawText: "口語", draftText: "全新的字")
        let added = Transcript(durationSeconds: 60, rawText: "口語補", draftText: "補的。")
        let point = InsertionPoint(offset: 3, in: "原本是另一份完全不同的字")
        XCTAssertFalse(target.insert(added, at: point))
        XCTAssertEqual(target.draftText, "全新的字\n\n補的。")
    }

    // MARK: 編輯框邊打邊變樣

    private typealias Styler = MarkdownStyler

    func test標題記號與標題字分開() {
        XCTAssertEqual(Styler.runs(in: "## 吸引力法則"), [
            .init(role: .headingMarker, range: NSRange(location: 0, length: 3)),
            .init(role: .headingText, range: NSRange(location: 3, length: 5)),
        ])
        XCTAssertEqual(Styler.runs(in: "##沒有空白不算"), [])
        XCTAssertEqual(Styler.runs(in: "####### 七個不算"), [])
    }

    func test粗體只認同一行成對的記號() {
        XCTAssertEqual(Styler.runs(in: "要**寫完**才睡"), [
            .init(role: .boldMarker, range: NSRange(location: 1, length: 2)),
            .init(role: .boldText, range: NSRange(location: 3, length: 2)),
            .init(role: .boldMarker, range: NSRange(location: 5, length: 2)),
        ])
        XCTAssertEqual(Styler.runs(in: "只有**一邊"), [])
        XCTAssertEqual(Styler.runs(in: "中間沒字****"), [])
    }

    func test清單的減號只認行首後面接空白() {
        XCTAssertEqual(Styler.runs(in: "- 洗澡"), [
            .init(role: .listMarker, range: NSRange(location: 0, length: 1)),
        ])
        let text = "睡覺\n- 洗澡\n散步 - 寫完" as NSString
        XCTAssertTrue(Styler.isListMarker(at: 3, in: text))
        XCTAssertFalse(Styler.isListMarker(at: 11, in: text), "句子中間的減號不換")
    }

    // MARK: 聽原音整段對字

    func test播到幾秒就標那一段() {
        let draft = ["一二三四", "", "五六七八九"].joined(separator: "\n")
        let transcript = Transcript(durationSeconds: 110, rawText: "口語", draftText: draft)
        let paragraphs = OriginalAudioSheet.paragraphs(of: transcript)
        XCTAssertEqual(OriginalAudioSheet.paragraph(at: 0, in: paragraphs)?.text, "一二三四")
        XCTAssertEqual(OriginalAudioSheet.paragraph(at: 59, in: paragraphs)?.text, "一二三四")
        XCTAssertEqual(OriginalAudioSheet.paragraph(at: 61, in: paragraphs)?.text, "五六七八九")
    }

    func test重點那句從句子開頭抓_不從逗號開始() {
        let draft = String(repeating: "甲", count: 30) + "。今天要聚焦在吸引力法則上面，要把它寫完。"
            + String(repeating: "乙", count: 30)
        let transcript = Transcript(durationSeconds: 100, rawText: "口語", draftText: draft)
        let text = OriginalAudioSheet.nearbyText(at: 50, in: transcript)
        XCTAssertTrue(text.hasPrefix("今天要聚焦"), text)
    }
}
