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

    private func date(month: Int, day: Int, hour: Int) throws -> Date {
        let components = DateComponents(year: 2026, month: month, day: day, hour: hour)
        return try XCTUnwrap(calendar.date(from: components))
    }

    private func groupTitle(for date: Date, now: Date) -> String {
        TranscriptListView.groupTitle(for: date, now: now, calendar: calendar)
    }
}
