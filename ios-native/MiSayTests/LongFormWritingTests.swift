@testable import MiSay
import XCTest

/// 2026-11-15 米：光用手機就要能在編輯區打出五千字以上的長文。新文稿、復原重做、大綱與尋找、字數目標。
final class LongFormWritingTests: XCTestCase {
    // MARK: 新文稿

    func test新文稿是空的文字稿_寫了字就不算空白() {
        var draft = Transcript.blankDraft()
        XCTAssertEqual(draft.draftText, "")
        XCTAssertTrue(draft.isWritten)
        XCTAssertTrue(draft.isBlankDraft)
        draft.draftText = "  \n"
        XCTAssertTrue(draft.isBlankDraft, "只有空白換行還是算沒寫")
        draft.draftText = "第一句"
        XCTAssertFalse(draft.isBlankDraft)
        XCTAssertTrue(draft.isWritten)
        XCTAssertEqual(TranscriptListView.lengthNote(for: draft), "自己打的")
    }

    func test空白新文稿接著錄_前面不多空兩行() {
        var draft = Transcript.blankDraft()
        draft.append(Transcript(durationSeconds: 60, rawText: "口語", draftText: "草稿"))
        XCTAssertEqual(draft.draftText, "草稿")
        XCTAssertEqual(draft.rawText, "口語")
        XCTAssertFalse(draft.isWritten)
    }

    func test字數目標存得進去讀得出來() throws {
        var draft = Transcript.blankDraft()
        draft.goalCharacters = 5000
        let data = try JSONEncoder().encode(draft)
        XCTAssertEqual(try JSONDecoder().decode(Transcript.self, from: data).goalCharacters, 5000)
        XCTAssertEqual(TranscriptDetailView.progress(count: 12, goal: nil), "12 字")
        XCTAssertEqual(TranscriptDetailView.progress(count: 12, goal: 500), "12／500 字")
    }

    // MARK: 復原、重做

    func test連著打的字算一步_停一下才是下一步() {
        let start = Date(timeIntervalSince1970: 0)
        var history = EditHistory()
        history.record(from: "", to: "一", now: start)
        history.record(from: "一", to: "一二", now: start.addingTimeInterval(0.5))
        history.record(from: "一二", to: "一二三", now: start.addingTimeInterval(5))
        XCTAssertEqual(history.undoStack.count, 2)
        XCTAssertEqual(history.undo(current: "一二三"), "一二")
        // 編輯框回報「字變成一二」：那是復原放上去的，不算新的修改。
        history.record(from: "一二三", to: "一二", now: start.addingTimeInterval(6))
        XCTAssertTrue(history.canRedo)
        XCTAssertEqual(history.undo(current: "一二"), "")
        history.record(from: "一二", to: "", now: start.addingTimeInterval(7))
        XCTAssertFalse(history.canUndo)
        XCTAssertEqual(history.redo(current: ""), "一二")
    }

    func test一次差很多字自己一步_新的修改清掉重做() {
        let start = Date(timeIntervalSince1970: 0)
        let pasted = String(repeating: "貼", count: 30)
        var history = EditHistory()
        history.record(from: "", to: "一", now: start)
        history.record(from: "一", to: "一" + pasted, now: start.addingTimeInterval(0.2))
        XCTAssertEqual(history.undoStack.count, 2)
        XCTAssertEqual(history.undo(current: "一" + pasted), "一")
        history.record(from: "一" + pasted, to: "一", now: start.addingTimeInterval(1))
        history.record(from: "一", to: "一新", now: start.addingTimeInterval(9))
        XCTAssertFalse(history.canRedo)
    }

    /// 2026-11-17：每一步只記改到的那幾個字。長稿中間改一個字，紀錄裡只有那一個字。
    func test每一步只記改到的字_長稿也一樣小() {
        let start = Date(timeIntervalSince1970: 0)
        let long = String(repeating: "長", count: 5000)
        var history = EditHistory()
        history.record(from: long + "尾", to: long + "改尾", now: start)
        XCTAssertEqual(
            history.undoStack,
            [EditHistory.Change(location: 5000, removed: "改", inserted: "")]
        )
        XCTAssertEqual(history.undo(current: long + "改尾"), long + "尾")
        XCTAssertEqual(history.redo(current: long + "尾"), long + "改尾")
    }

    func test改到emoji不會切成半個() {
        let change = EditHistory.Change.between("我😀們", "我😃們")
        XCTAssertEqual(change.removed, "😀")
        XCTAssertEqual(change.inserted, "😃")
        XCTAssertEqual(change.applied(to: "我😀們"), "我😃們")
        XCTAssertEqual(change.inverse.applied(to: "我😃們"), "我😀們")
    }

    func test紀錄對不上畫面就不復原_也不亂改() {
        var history = EditHistory()
        history.record(from: "一二", to: "一二三", now: Date(timeIntervalSince1970: 0))
        XCTAssertNil(history.undo(current: "完全不一樣"))
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func test連打很多次_退回去還是那一步開始前() {
        let start = Date(timeIntervalSince1970: 0)
        var history = EditHistory()
        var text = "開頭"
        for (index, character) in "一二三四五".enumerated() {
            let next = text + String(character)
            history.record(from: text, to: next, now: start.addingTimeInterval(Double(index) * 0.3))
            text = next
        }
        XCTAssertEqual(history.undoStack.count, 1)
        XCTAssertEqual(history.undo(current: text), "開頭")
    }

    func test復原後游標放在變動那段的後面() {
        XCTAssertEqual(EditHistory.changeEnd(from: "一二三四五", to: "一二改四五"), 3)
        XCTAssertEqual(EditHistory.changeEnd(from: "一二", to: "一二三四"), 4)
        XCTAssertEqual(EditHistory.changeEnd(from: "一二三四", to: "一四"), 1)
    }

    // MARK: 大綱與尋找

    private let article = ["# 第一章", "內文一", "", "## 小節", "內文 Apple apple", "#標籤不是標題"]
        .joined(separator: "\n")

    func test大綱照標題列_記得從第幾個字開始() {
        let headings = DraftOutline.headings(in: article)
        XCTAssertEqual(headings.map(\.title), ["第一章", "小節"])
        XCTAssertEqual(headings.map(\.level), [1, 2])
        XCTAssertEqual(headings.map(\.offset), [0, 11])
    }

    func test從電腦貼來的換行_位置照樣對得上() {
        // `\r\n` 在 Swift 是一個字。以前每一行多算一個，第二個標題會偏兩個字。
        let pasted = "# 甲\r\n內文\r\n## 乙\r\n尾"
        let headings = DraftOutline.headings(in: pasted)
        XCTAssertEqual(headings.map(\.title), ["甲", "乙"])
        XCTAssertEqual(headings.map(\.offset), [0, 7])
        let characters = Array(pasted)
        XCTAssertEqual(String(characters[7 ..< 11]), "## 乙")

        let swapped = DraftOutline.moving(headings, from: 1, toOffset: 0, in: pasted)
        XCTAssertEqual(swapped, "## 乙\r\n尾\r\n# 甲\r\n內文")
    }

    func test沒有標題就列每段開頭() {
        let paragraphs = DraftOutline.paragraphs(in: "甲\n\n乙丙")
        XCTAssertEqual(paragraphs.map(\.title), ["甲", "乙丙"])
        XCTAssertEqual(paragraphs.map(\.offset), [0, 3])
        XCTAssertTrue(DraftOutline.headings(in: "甲\n\n乙丙").isEmpty)
    }

    func test尋找不分大小寫_給每一處的位置與長度() {
        let matches = DraftOutline.matches(of: " apple ", in: article)
        XCTAssertEqual(matches.map(\.offset), [20, 26])
        XCTAssertEqual(matches.map(\.length), [5, 5])
        XCTAssertEqual(matches.first?.range, 20 ..< 25)
        XCTAssertTrue(matches.first?.title.contains("Apple") ?? false)
        XCTAssertTrue(DraftOutline.matches(of: "  ", in: article).isEmpty)
        XCTAssertTrue(DraftOutline.matches(of: "找不到", in: article).isEmpty)
    }

    // MARK: 第三批：新的編輯框的位置換算

    func test位置換算_有emoji時UTF16跟第幾個字不一樣() {
        let text = "一😀二三"
        // 😀 在 UTF-16 佔兩格：「二」是第 2 個字，UTF-16 從 3 開始。
        func utf16(_ location: Int, _ length: Int) -> NSRange {
            NSRange(location: location, length: length)
        }
        XCTAssertEqual(TextOffsets.characters(of: utf16(3, 1), in: text), 2 ..< 3)
        XCTAssertEqual(TextOffsets.characters(of: utf16(5, 0), in: text), 4 ..< 4)
        XCTAssertEqual(TextOffsets.utf16Range(of: 2 ..< 4, in: text), utf16(3, 2))
        XCTAssertEqual(TextOffsets.utf16Range(of: 9 ..< 9, in: text), utf16(5, 0))
        XCTAssertEqual(TextOffsets.clamped(utf16(4, 9), length: 5), utf16(4, 1))
        XCTAssertEqual(TextOffsets.characters(of: utf16(99, 3), in: text), 4 ..< 4)
    }

    // MARK: 第二批：版本紀錄、全部取代、整段搬動

    func test留版_跟AI那份一樣不留_重複不留_最多八版() {
        var transcript = Transcript(
            durationSeconds: 60,
            rawText: "口語",
            draftText: "AI 版",
            originalDraft: "AI 版"
        )
        transcript.keepVersion()
        XCTAssertNil(transcript.versions, "AI 剛整理好的那份本來就留著")
        transcript.draftText = "改一"
        transcript.keepVersion()
        transcript.keepVersion()
        XCTAssertEqual(transcript.versions?.map(\.text), ["改一"])
        transcript.draftText = "  \n"
        transcript.keepVersion()
        XCTAssertEqual(transcript.versions?.count, 1, "空的不留")
        for index in 0 ..< 10 {
            transcript.draftText = "第 \(index) 次"
            transcript.keepVersion()
        }
        XCTAssertEqual(transcript.versions?.count, Transcript.maxVersions)
        XCTAssertEqual(transcript.versions?.first?.text, "第 2 次")
        XCTAssertEqual(transcript.versions?.last?.text, "第 9 次")
    }

    func test全部取代不分大小寫_回換了幾處() {
        let replaced = DraftOutline.replacingAll("apple", with: "梨", in: article)
        XCTAssertEqual(replaced.count, 2)
        XCTAssertTrue(replaced.text.contains("內文 梨 梨"))
        let deleted = DraftOutline.replacingAll("內文", with: "", in: "內文一、內文二")
        XCTAssertEqual(deleted.text, "一、二")
        let untouched = DraftOutline.replacingAll("  ", with: "x", in: article)
        XCTAssertEqual(untouched.count, 0)
        XCTAssertEqual(untouched.text, article)
        XCTAssertEqual(OutlineSheet.replaceTitle(count: 3, isDeleting: false), "全部換掉（3 處）")
        XCTAssertEqual(OutlineSheet.replaceTitle(count: 3, isDeleting: true), "全部刪掉（3 處）")
    }

    func test大綱搬動_整段跟著走_前言與空行留在原位() {
        let text = ["前言", "", "# 甲", "甲文", "", "# 乙", "乙文", "", "# 丙", "丙文"]
            .joined(separator: "\n")
        let headings = DraftOutline.headings(in: text)
        let lastToFirst = DraftOutline.moving(headings, from: 2, toOffset: 0, in: text)
        XCTAssertEqual(lastToFirst, "前言\n\n# 丙\n丙文\n\n# 甲\n甲文\n\n# 乙\n乙文")
        let firstDownOne = DraftOutline.moving(headings, from: 0, toOffset: 2, in: text)
        XCTAssertEqual(firstDownOne, "前言\n\n# 乙\n乙文\n\n# 甲\n甲文\n\n# 丙\n丙文")
        let firstToLast = DraftOutline.moving(headings, from: 0, toOffset: 3, in: text)
        XCTAssertEqual(firstToLast, "前言\n\n# 乙\n乙文\n\n# 丙\n丙文\n\n# 甲\n甲文")
        XCTAssertEqual(DraftOutline.moving(headings, from: 9, toOffset: 0, in: text), text)
    }
}
