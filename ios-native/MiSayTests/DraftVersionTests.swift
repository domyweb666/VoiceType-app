@testable import MiSay
import XCTest

/// 2026-11-24 版本紀錄留久一點；什麼樣的新文稿可以直接刪。
final class DraftVersionTests: XCTestCase {
    func test更早的版本每天留最後一版_最多十四天() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Taipei"))
        let day: TimeInterval = 24 * 60 * 60
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        var versions: [DraftVersion] = []
        // 20 天，每天早晚各一版；最後一天再連改 8 版。
        for index in 0 ..< 20 {
            let morning = start.addingTimeInterval(Double(index) * day + 60)
            versions.append(DraftVersion(savedAt: morning, text: "第\(index)天早"))
            let evening = morning.addingTimeInterval(day / 2)
            versions.append(DraftVersion(savedAt: evening, text: "第\(index)天晚"))
        }
        let lastDay = start.addingTimeInterval(19 * day + day / 2)
        for index in 0 ..< 8 {
            let savedAt = lastDay.addingTimeInterval(Double(index + 1) * 600)
            versions.append(DraftVersion(savedAt: savedAt, text: "連改\(index)"))
        }

        let kept = Transcript.prunedVersions(versions, calendar: calendar).map(\.text)
        let expectedDaily = (5 ... 18).map { "第\($0)天晚" }
        let expectedRecent = (0 ..< 8).map { "連改\($0)" }
        XCTAssertEqual(kept, expectedDaily + expectedRecent)
        XCTAssertEqual(expectedDaily.count, Transcript.maxDailyVersions)
        // 再整理一次不會越丟越少。
        let again = Transcript.prunedVersions(
            Transcript.prunedVersions(versions, calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(again.map(\.text), kept)
    }

    func test寫過又清空_取過標題_改寫來的不算空白新文稿() {
        var cleared = Transcript.blankDraft()
        cleared.versions = [DraftVersion(text: "寫過的字")]
        XCTAssertFalse(cleared.isBlankDraft)
        var titled = Transcript.blankDraft()
        titled.title = "標題"
        XCTAssertFalse(titled.isBlankDraft)
        var rewritten = Transcript.blankDraft()
        rewritten.sourceID = UUID()
        XCTAssertFalse(rewritten.isBlankDraft)
    }
}
