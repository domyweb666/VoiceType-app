@testable import MiSay
import XCTest

/// W6 標籤與合併：合併照錄的時間接、原本的字不動、新的一篇不再學一次；標籤去重、清掉 #、太長不收。
final class TagsAndMergeTests: XCTestCase {
    func test合併照錄的時間接_舊的在前_長度與重點秒數接起來() throws {
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)
        var first = Transcript(createdAt: early, durationSeconds: 60, rawText: "一的口語")
        first.applyPolish("一的文字稿。", model: "m", style: .keepVoice)
        first.marks = [10]
        var second = Transcript(createdAt: late, durationSeconds: 30, rawText: "二的口語")
        second.applyPolish("二的文字稿。", model: "m", style: .keepVoice)
        second.marks = [5]

        let now = Date(timeIntervalSince1970: 3000)
        let merged = try XCTUnwrap(Transcript.merged([second, first], at: now))

        XCTAssertNotEqual(merged.id, first.id)
        XCTAssertEqual(merged.createdAt, now)
        XCTAssertEqual(merged.rawText, "一的口語\n\n二的口語")
        XCTAssertEqual(merged.draftText, "一的文字稿。\n\n二的文字稿。")
        XCTAssertEqual(merged.originalDraft, "一的文字稿。\n\n二的文字稿。")
        XCTAssertEqual(merged.durationSeconds, 90)
        XCTAssertEqual(merged.marks, [10, 65])
        XCTAssertNotNil(merged.combinedAt, "好幾段接起來的，不給重新轉錄、不給播原音")
    }

    func test合併後不再學一次_原本那幾篇沒改改過的字照用() throws {
        var first = Transcript(
            createdAt: Date(timeIntervalSince1970: 1),
            durationSeconds: 1,
            rawText: "甲"
        )
        first.applyPolish("甲。", model: "m", style: .keepVoice)
        first.draftText = "我改過的甲。"
        let second = Transcript(
            createdAt: Date(timeIntervalSince1970: 2),
            durationSeconds: 1,
            rawText: "乙"
        )

        let merged = try XCTUnwrap(Transcript.merged([first, second]))
        XCTAssertEqual(merged.draftText, "我改過的甲。\n\n乙")
        XCTAssertNil(merged.unlearnedEdit)
        XCTAssertEqual(first.draftText, "我改過的甲。", "原本那篇不動")
    }

    func test少於兩篇不合併() {
        XCTAssertNil(Transcript.merged([]))
        XCTAssertNil(Transcript.merged([Transcript(durationSeconds: 1, rawText: "一篇")]))
    }

    func test標籤合起來不重複_照字排() throws {
        var first = Transcript(
            createdAt: Date(timeIntervalSince1970: 1),
            durationSeconds: 1,
            rawText: "甲"
        )
        first.tags = ["課程", "Podcast"]
        var second = Transcript(
            createdAt: Date(timeIntervalSince1970: 2),
            durationSeconds: 1,
            rawText: "乙"
        )
        second.tags = ["podcast", "讀書心得"]

        XCTAssertEqual(Transcript.tagsInUse([first, second]).count, 3)
        let merged = try XCTUnwrap(Transcript.merged([first, second]))
        XCTAssertEqual(merged.tags?.count, 3)
        XCTAssertNil(try XCTUnwrap(Transcript.merged([
            Transcript(createdAt: Date(timeIntervalSince1970: 1), durationSeconds: 1, rawText: "甲"),
            Transcript(createdAt: Date(timeIntervalSince1970: 2), durationSeconds: 1, rawText: "乙"),
        ])).tags)
    }

    func test標籤清掉井號與空白_空的和太長的不收() {
        XCTAssertEqual(TagEditorSheet.cleaned("  #讀書心得 "), "讀書心得")
        XCTAssertEqual(TagEditorSheet.cleaned("＃課程"), "課程")
        XCTAssertNil(TagEditorSheet.cleaned("  # "))
        XCTAssertNil(TagEditorSheet.cleaned(String(
            repeating: "字",
            count: TagEditorSheet.maxTagLength + 1
        )))
    }

    func test畫面上的字() {
        XCTAssertEqual(TranscriptDetailView.tagMenuTitle([]), "標籤…")
        XCTAssertEqual(TranscriptDetailView.tagMenuTitle(["課程", "Podcast"]), "標籤：課程、Podcast")
        XCTAssertEqual(TranscriptListView.tagLine(["課程", "Podcast"]), "#課程 #Podcast")
        XCTAssertEqual(TranscriptListView.mergeButtonTitle(selectedCount: 1), "選兩篇以上來合併")
        XCTAssertEqual(TranscriptListView.mergeButtonTitle(selectedCount: 3), "合併成一篇（3 篇）")
    }

    func test舊檔沒有標籤欄也讀得出來() throws {
        let json = """
        {"id":"\(UUID().uuidString)","createdAt":"2026-11-01T00:00:00Z","durationSeconds":3,
        "rawText":"舊的","updatedAt":"2026-11-01T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertNil(try decoder.decode(Transcript.self, from: Data(json.utf8)).tags)
    }
}
