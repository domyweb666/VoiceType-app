@testable import MiSay
import UIKit
import XCTest

/// 組塊 LA：錄音狀態變成即時動態的內容。系統那一層只有真機驗得到。
final class RecordingActivityTests: XCTestCase {
    private typealias Plan = RecordingActivityPlan

    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func time(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    private func status(
        elapsed: Double,
        isPaused: Bool = false,
        isWaiting: Bool = false
    ) -> Plan.Status {
        Plan.Status(isPaused: isPaused, isWaitingForSound: isWaiting, elapsedSeconds: elapsed)
    }

    /// 計時畫面上會看到幾秒。
    private func shownSeconds(_ state: Plan.State, at now: Date) -> TimeInterval {
        min(state.pausedAt ?? now, state.timerEnd).timeIntervalSince(state.timerStart)
    }

    private func display(_ state: Plan.State, isStale: Bool = false) -> RecordingActivityDisplay {
        RecordingActivityDisplay(state: state, isStale: isStale)
    }

    func test即時動態開錄從零開始走() throws {
        var plan = Plan()
        let frame = try XCTUnwrap(plan.next(status(elapsed: 0), appState: .active, now: start))
        XCTAssertEqual(frame.state.phase, .recording)
        XCTAssertNil(frame.state.pausedAt)
        XCTAssertTrue(frame.canStart)
        XCTAssertEqual(shownSeconds(frame.state, at: time(10)), 10)
        XCTAssertEqual(display(frame.state).title, "錄音中")
    }

    func test即時動態暫停停在累計時間續錄從累計接著走() throws {
        var plan = Plan()
        _ = plan.next(status(elapsed: 0), appState: .active, now: start)
        let paused = try XCTUnwrap(plan.next(
            status(elapsed: 30, isPaused: true, isWaiting: true),
            appState: .active,
            now: time(31)
        ))
        XCTAssertEqual(paused.state.phase, .paused)
        XCTAssertEqual(shownSeconds(paused.state, at: time(90)), 30, "暫停時不准走")

        let waiting = try XCTUnwrap(plan.next(
            status(elapsed: 30, isWaiting: true),
            appState: .active,
            now: time(40)
        ))
        XCTAssertEqual(waiting.state.phase, .waitingForSound)
        XCTAssertEqual(shownSeconds(waiting.state, at: time(50)), 30, "還沒聲音也不准走")

        let resumed = try XCTUnwrap(
            plan.next(status(elapsed: 31), appState: .active, now: time(50))
        )
        XCTAssertEqual(resumed.state.phase, .recording)
        XCTAssertEqual(shownSeconds(resumed.state, at: time(60)), 41)
    }

    func test即時動態沒變就不送滿一分鐘續期過期時間往後推() throws {
        var plan = Plan()
        let first = try XCTUnwrap(plan.next(status(elapsed: 0), appState: .active, now: start))
        for second in 1 ..< 60 {
            XCTAssertNil(plan.next(
                status(elapsed: Double(second) - 0.3),
                appState: .active,
                now: time(Double(second))
            ))
        }
        let renewed = try XCTUnwrap(
            plan.next(status(elapsed: 59.7), appState: .active, now: time(60))
        )
        XCTAssertEqual(renewed.staleDate, time(60 + Plan.staleAfterSeconds))
        XCTAssertEqual(renewed.state.timerStart, first.state.timerStart, "續期時數字不准跳")
        XCTAssertFalse(renewed.canStart)
    }

    func test即時動態長錄音在背景不會過期() {
        var plan = Plan()
        var staleDate = start
        for second in 0 ..< 4 * 3600 {
            let now = time(Double(second))
            if second > 0 {
                XCTAssertGreaterThan(staleDate.timeIntervalSince(now), 180)
            }
            let appState: UIApplication.State = second == 0 ? .active : .background
            let frame = plan.next(status(elapsed: Double(second)), appState: appState, now: now)
            staleDate = frame?.staleDate ?? staleDate
        }
    }

    func test即時動態計時差太多才重新對() {
        var plan = Plan()
        _ = plan.next(status(elapsed: 0), appState: .active, now: start)
        XCTAssertNil(plan.next(status(elapsed: 3.5), appState: .active, now: time(5)))
        let frame = plan.next(status(elapsed: 3.5), appState: .active, now: time(6))
        XCTAssertEqual(frame?.state.timerStart, time(2.5))
    }

    func test即時動態暫停中一樣一分鐘才送一次() {
        var plan = Plan()
        let paused = status(elapsed: 30, isPaused: true, isWaiting: true)
        XCTAssertNotNil(plan.next(paused, appState: .background, now: start))
        XCTAssertNil(plan.next(paused, appState: .background, now: time(59)))
        let renewed = plan.next(paused, appState: .background, now: time(60))
        XCTAssertEqual(renewed.map { shownSeconds($0.state, at: time(100)) }, 30)
    }

    func test即時動態只在前景開回前景再試一次() {
        var plan = Plan()
        XCTAssertEqual(
            plan.next(status(elapsed: 0), appState: .background, now: start)?.canStart, false
        )
        XCTAssertEqual(
            plan.next(status(elapsed: 5), appState: .active, now: time(5))?.canStart, true
        )
        XCTAssertNil(plan.next(status(elapsed: 6), appState: .active, now: time(6)))
    }

    func test即時動態滑掉不再冒出來滿八小時可以再開() {
        let limit = RecordingActivityHost.systemLimitSeconds
        XCTAssertTrue(RecordingActivityHost.canStart(lastStartedAt: nil, now: start))
        XCTAssertFalse(RecordingActivityHost.canStart(lastStartedAt: start, now: time(60)))
        XCTAssertTrue(RecordingActivityHost.canStart(lastStartedAt: start, now: time(limit)))
    }

    func test即時動態過期改說法計時收起來() {
        let state = Plan.state(for: status(elapsed: 30), after: nil, now: start)
        let stale = display(state, isStale: true)
        XCTAssertEqual(stale.title, "錄音已停")
        XCTAssertEqual(stale.hint, "打開米說看看")
        XCTAssertFalse(stale.showsTimer)
        XCTAssertTrue(display(state).showsTimer)
        XCTAssertEqual(shownSeconds(state, at: time(9999)), 30 + Plan.staleAfterSeconds)
    }

    func test即時動態計時框的寬度先留給下次更新前() {
        let short = Plan.state(for: status(elapsed: 60), after: nil, now: start)
        XCTAssertEqual(display(short).timerTemplate, "00:00")
        let almostHour = Plan.state(for: status(elapsed: 3400), after: nil, now: start)
        XCTAssertEqual(display(almostHour).timerTemplate, "0:00:00")
        let long = Plan.state(for: status(elapsed: 36000), after: nil, now: start)
        XCTAssertEqual(display(long).timerTemplate, "00:00:00")
    }

    func test即時動態計時區間不會顛倒() {
        let state = Plan.State(
            phase: .recording,
            timerStart: time(10),
            timerEnd: start,
            pausedAt: nil
        )
        XCTAssertEqual(state.timerRange, time(10) ... time(10))
    }
}
