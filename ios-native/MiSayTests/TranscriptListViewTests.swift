@testable import MiSay
import XCTest

/// 2026-11-07 統一風格：清單分「今天／本週／更早」。分組只看行事曆，不看時間長短。
final class TranscriptListViewTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei") ?? .current
        calendar.firstWeekday = 1
        return calendar
    }()

    func test今天本週更早照行事曆分() throws {
        // 2026-11-07 是星期六；週日起算，11/1（日）到 11/7（六）是同一週。
        let now = try date(month: 11, day: 7, hour: 15)
        let thisMorning = try date(month: 11, day: 7, hour: 1)
        let tuesday = try date(month: 11, day: 3, hour: 20)
        let lastSaturday = try date(month: 10, day: 31, hour: 23)

        XCTAssertEqual(groupTitle(for: thisMorning, now: now), "今天")
        XCTAssertEqual(groupTitle(for: tuesday, now: now), "本週")
        XCTAssertEqual(groupTitle(for: lastSaturday, now: now), "更早")
    }

    func test照最後改的時間排_同時間照錄的時間() throws {
        let morning = try date(month: 11, day: 7, hour: 8)
        let noon = try date(month: 11, day: 7, hour: 12)
        let edited = Transcript(
            createdAt: morning,
            durationSeconds: 1,
            rawText: "早上錄、中午改",
            updatedAt: noon
        )
        let untouched = Transcript(
            createdAt: noon,
            durationSeconds: 1,
            rawText: "中午錄",
            updatedAt: noon
        )
        let older = Transcript(
            createdAt: noon,
            durationSeconds: 1,
            rawText: "早上",
            updatedAt: morning
        )
        XCTAssertEqual(
            TranscriptListView.listOrder([older, edited, untouched]).map(\.rawText),
            ["中午錄", "早上錄、中午改", "早上"]
        )
    }

    func test搜尋含標題不分大小寫() {
        var transcript = Transcript(durationSeconds: 1, rawText: "口語", draftText: "文字稿")
        transcript.title = "Podcast 企劃"
        XCTAssertTrue(TranscriptListView.matches(transcript, keyword: "podcast"))
        XCTAssertTrue(TranscriptListView.matches(transcript, keyword: "口語"))
        XCTAssertTrue(TranscriptListView.matches(transcript, keyword: "文字"))
        XCTAssertFalse(TranscriptListView.matches(transcript, keyword: "電子報"))
    }

    func test草稿與已發布() {
        var transcript = Transcript(durationSeconds: 0, rawText: "", draftText: "寫的")
        XCTAssertTrue(TranscriptListView.PublishFilter.draft.includes(transcript))
        XCTAssertFalse(rowSubtitle(transcript).contains("已發布"))
        transcript.publishedAt = Date()
        XCTAssertTrue(TranscriptListView.PublishFilter.published.includes(transcript))
        XCTAssertFalse(TranscriptListView.PublishFilter.draft.includes(transcript))
        XCTAssertTrue(rowSubtitle(transcript).hasSuffix("・自己打的・已發布"))
    }

    func test改寫來的寫改成哪一種_標題只有空白不算() {
        var transcript = Transcript(durationSeconds: 0, rawText: "", draftText: "串文")
        transcript.sourceID = UUID()
        transcript.sourceKind = RewriteKind.threads.rawValue
        XCTAssertEqual(TranscriptListView.lengthNote(for: transcript), "改寫：Threads 串文")
        XCTAssertNil(TranscriptListView.rowTitle(of: transcript))
        transcript.title = " \n"
        XCTAssertNil(TranscriptListView.rowTitle(of: transcript))
        transcript.title = " 標題 "
        XCTAssertEqual(TranscriptListView.rowTitle(of: transcript), "標題")
    }

    private func rowSubtitle(_ transcript: Transcript) -> String {
        TranscriptListView.rowSubtitle(for: transcript, showsDate: true)
    }

    private func date(month: Int, day: Int, hour: Int) throws -> Date {
        let components = DateComponents(year: 2026, month: month, day: day, hour: hour)
        return try XCTUnwrap(calendar.date(from: components))
    }

    private func groupTitle(for date: Date, now: Date) -> String {
        TranscriptListView.groupTitle(for: date, now: now, calendar: calendar)
    }
}
