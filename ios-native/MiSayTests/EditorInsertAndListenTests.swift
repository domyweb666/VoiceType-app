@testable import MiSay
import XCTest

/// v0.2.7（2026-11-09 米的四點）：在游標處接著錄、聽原音整段對字。
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

    // MARK: 聽原音逐句跟讀（2026-11-15）

    /// 兩段各 100 秒：第一段 10 個字、第二段 20 個字。
    private func twoSpanTranscript(marks: [Double]? = nil) -> Transcript {
        var transcript = Transcript(
            durationSeconds: 200,
            rawText: "一二三四。五六七八。" + "甲乙丙丁戊己庚辛壬。" + "子丑寅卯辰巳午未申。"
        )
        transcript.timeline = [
            TimelineSpan(startSeconds: 0, endSeconds: 100, characterCount: 10),
            TimelineSpan(startSeconds: 100, endSeconds: 200, characterCount: 20),
        ]
        transcript.marks = marks
        return transcript
    }

    func test每句的時間在自己那一段裡照字數估() {
        let transcript = twoSpanTranscript()
        XCTAssertTrue(SpokenTimeline.isPrecise(transcript))
        let sentences = SpokenTimeline.sentences(of: transcript)
        XCTAssertEqual(sentences.map(\.text), ["一二三四。", "五六七八。", "甲乙丙丁戊己庚辛壬。", "子丑寅卯辰巳午未申。"])
        XCTAssertEqual(sentences.map(\.start), [0, 50, 100, 150])
        XCTAssertEqual(sentences.last?.end, 200)
        // 照整篇字數比例的話，第三句會被估在 66 秒，差了半分鐘。
        XCTAssertEqual(SpokenTimeline.sentence(at: 99, in: sentences)?.text, "五六七八。")
        XCTAssertEqual(SpokenTimeline.sentence(at: 101, in: sentences)?.text, "甲乙丙丁戊己庚辛壬。")
    }

    func test對照表字數對不上就照整篇估() {
        var transcript = twoSpanTranscript()
        transcript.timeline = [TimelineSpan(startSeconds: 0, endSeconds: 100, characterCount: 7)]
        XCTAssertFalse(SpokenTimeline.isPrecise(transcript))
        let sentences = SpokenTimeline.sentences(of: transcript)
        XCTAssertEqual(sentences[2].start, 200.0 * 10 / 30, accuracy: 0.001)
    }

    func test重點是按下去那句加前一句() {
        let transcript = twoSpanTranscript(marks: [10, 160])
        let sentences = SpokenTimeline.sentences(of: transcript)
        let passages = SpokenTimeline.passages(marks: transcript.marks ?? [], in: sentences)
        XCTAssertEqual(passages.map(\.text), ["一二三四。", "甲乙丙丁戊己庚辛壬。子丑寅卯辰巳午未申。"])
        XCTAssertEqual(passages.map(\.start), [0, 100])
        XCTAssertEqual(passages.last?.sentenceIndexes, [2, 3])
    }

    func test太長沒句號的句子在逗號斷開_一列湊滿才換() {
        let long = String(repeating: "字", count: 29) + "，" + String(repeating: "詞", count: 5) + "，尾"
        let sentences = SpokenTimeline.sentences(of: Transcript(durationSeconds: 60, rawText: long))
        XCTAssertEqual(sentences.map(\.text.count), [30, 7])
        let many = (0 ..< 5).map { _ in String(repeating: "句", count: 49) + "。" }.joined()
        let blocks = SpokenTimeline.blocks(
            SpokenTimeline.sentences(of: Transcript(durationSeconds: 60, rawText: many))
        )
        XCTAssertEqual(blocks.map(\.sentences.count), [3, 2])
    }

    func test進度檔少一段的字就不給對照表() {
        let segments = [
            WAVSegmenter.Segment(startFrame: 0, endFrame: 160),
            WAVSegmenter.Segment(startFrame: 160, endFrame: 480),
        ]
        XCTAssertNil(SpokenTimeline.spans(segments: segments, texts: [0: "甲"], framesPerSecond: 16))
        let spans = SpokenTimeline.spans(
            segments: segments,
            texts: [0: "甲", 1: "乙丙"],
            framesPerSecond: 16
        )
        XCTAssertEqual(spans?.map(\.endSeconds), [10, 30])
        XCTAssertEqual(spans?.map(\.characterCount), [1, 2])
    }

    func test接著錄之後對照表作廢() {
        var transcript = twoSpanTranscript()
        transcript.append(Transcript(durationSeconds: 60, rawText: "後面接的"))
        XCTAssertNil(transcript.timeline)
    }
}
