@testable import MiSay
import XCTest

/// 2026-11-08 文字稿頁的統計卡：字數不算空白、速度與節省時間的算法、時間怎麼寫。
final class DictationStatsTests: XCTestCase {
    func test字數不算空白換行_口語稿文字稿分開算() {
        let transcript = Transcript(durationSeconds: 60, rawText: "那 我們\n開始", draftText: "我們開始。")
        let stats = DictationStats(transcripts: [transcript])

        XCTAssertEqual(stats.spokenCharacters, 5)
        XCTAssertEqual(stats.writtenCharacters, 5)
    }

    func test速度是每分鐘口語稿字數() {
        let transcript = Transcript(durationSeconds: 30, rawText: String(repeating: "字", count: 90))

        XCTAssertEqual(DictationStats(transcripts: [transcript]).charactersPerMinute, 180)
    }

    func test節省時間是打字時間減講話時間_不給負數() {
        // 400 字用打的要 10 分鐘，講了 2 分鐘，省 8 分鐘。
        let fast = Transcript(durationSeconds: 120, rawText: String(repeating: "字", count: 400))
        XCTAssertEqual(DictationStats(transcripts: [fast]).savedSeconds, 480, accuracy: 0.001)

        // 講得比打得慢：0，不是負的。
        let slow = Transcript(durationSeconds: 600, rawText: "嗯")
        XCTAssertEqual(DictationStats(transcripts: [slow]).savedSeconds, 0)
    }

    func test沒有錄音時速度是零() {
        XCTAssertEqual(DictationStats(transcripts: []).charactersPerMinute, 0)
    }

    func test時間的寫法() {
        assertDuration(45, "45", "秒")
        assertDuration(12 * 60 + 20, "12", "分鐘")
        assertDuration(2 * 3600, "2", "小時")
        assertDuration(3 * 3600 + 5 * 60, "3 小時 5", "分")
    }

    func test首頁那一行_本週有講講本週_沒有講累計_一篇都沒有不顯示() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 11)))
        let lastMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: -1, to: now))
        // 400 字講 2 分鐘：打字要 10 分鐘，省 8 分鐘。
        let recent = Transcript(
            createdAt: now,
            durationSeconds: 120,
            rawText: String(repeating: "字", count: 400)
        )
        let old = Transcript(createdAt: lastMonth, durationSeconds: 600, rawText: "嗯")

        XCTAssertNil(DictationStats.homeSummary(for: [], now: now, calendar: calendar))
        XCTAssertEqual(
            DictationStats.homeSummary(for: [recent, old], now: now, calendar: calendar),
            "本週講了 2 分鐘・約 400 字・省下 8 分鐘"
        )
        // 講得比打得慢，沒省到時間就不寫「省下」。
        XCTAssertEqual(
            DictationStats.homeSummary(for: [old], now: now, calendar: calendar),
            "累計講了 10 分鐘・約 1 字"
        )
    }

    private func assertDuration(
        _ seconds: Double,
        _ value: String,
        _ unit: String,
        line: UInt = #line
    ) {
        let duration = DictationStats.duration(seconds)
        XCTAssertEqual(duration.value, value, line: line)
        XCTAssertEqual(duration.unit, unit, line: line)
    }
}
