@testable import MiSay
import XCTest

/// 引 0、引 1（2026-11-15）：聚光燈引導。洞套不套得準、觸控擋不擋得住要真機看；這裡驗步驟怎麼走、
/// 「看過了」什麼時候寫、文案長度、洞的動畫數值、打字機停多久。
final class CoachMarksTests: XCTestCase {
    private var defaults = UserDefaults.standard
    private let suiteName = "CoachMarksTests"

    override func setUpWithError() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test五步每步內文四十字以內() {
        XCTAssertEqual(CoachTour.steps.count, 5)
        XCTAssertEqual(Set(CoachTour.steps.map(\.id)).count, 5)
        for step in CoachTour.steps {
            XCTAssertLessThanOrEqual(step.body.count, 40, step.id)
            XCTAssertFalse(step.title.isEmpty)
        }
    }

    func test一步一步走完才記看過() {
        let coach = CoachController(defaults: defaults)
        XCTAssertNil(coach.currentStep)
        coach.startIfFirstTime()
        XCTAssertEqual(coach.currentStep?.id, "hello")
        for expected in ["edit", "copy", "more", "done"] {
            coach.next()
            XCTAssertEqual(coach.currentStep?.id, expected)
            XCTAssertFalse(coach.hasCompleted)
        }
        coach.next()
        XCTAssertFalse(coach.isActive)
        XCTAssertNil(coach.currentStep)
        XCTAssertTrue(coach.hasCompleted)
    }

    func test跳過立刻結束也記看過() {
        let coach = CoachController(defaults: defaults)
        coach.startIfFirstTime()
        coach.next()
        coach.frames[CoachTour.bodyTarget] = CGRect(x: 0, y: 100, width: 300, height: 160)
        coach.skip()
        XCTAssertFalse(coach.isActive)
        XCTAssertTrue(coach.hasCompleted)
        XCTAssertTrue(coach.frames.isEmpty)
    }

    func test看過就不再自己開始但可以手動重看() {
        let first = CoachController(defaults: defaults)
        first.startIfFirstTime()
        first.skip()
        let second = CoachController(defaults: defaults)
        second.startIfFirstTime()
        XCTAssertFalse(second.isActive)
        second.start()
        XCTAssertEqual(second.currentStep?.id, "hello")
    }

    func test中途沒走完下次從第一步重來() {
        let first = CoachController(defaults: defaults)
        first.startIfFirstTime()
        first.next()
        first.next()
        let second = CoachController(defaults: defaults)
        XCTAssertFalse(second.hasCompleted)
        second.startIfFirstTime()
        XCTAssertEqual(second.currentStep?.id, "hello")
    }

    func test沒在進行時按下一步或跳過都沒事() {
        let coach = CoachController(defaults: defaults)
        coach.next()
        coach.skip()
        XCTAssertFalse(coach.isActive)
        XCTAssertFalse(coach.hasCompleted)
    }

    func test洞的四個數值進出動畫是同一組() {
        var shape = SpotlightShape(
            hole: CGRect(x: 10, y: 20, width: 30, height: 40),
            cornerRadius: Token.Coach.holeRadius
        )
        let data = shape.animatableData
        shape.hole = .zero
        shape.animatableData = data
        XCTAssertEqual(shape.hole, CGRect(x: 10, y: 20, width: 30, height: 40))
    }

    func test黑幕挖掉洞的那一塊() {
        let hole = CGRect(x: 100, y: 100, width: 80, height: 40)
        let shape = SpotlightShape(hole: hole, cornerRadius: Token.Coach.holeRadius)
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 400, height: 800))
        XCTAssertTrue(path.contains(CGPoint(x: 20, y: 20), eoFill: true))
        XCTAssertFalse(path.contains(CGPoint(x: 140, y: 120), eoFill: true))
    }

    func test打字機標點後多停一下() {
        XCTAssertEqual(CoachCard.delay(after: "字"), Token.Coach.typeInterval)
        XCTAssertEqual(
            CoachCard.delay(after: "。"),
            Token.Coach.typeInterval + Token.Coach.typePause
        )
        XCTAssertGreaterThan(CoachCard.delay(after: "，"), CoachCard.delay(after: "我"))
    }

    func test引導用的三個動作各有不動的那一張() {
        XCTAssertNotEqual(StickFigure.Pose.still(for: .waving), StickFigure.Pose())
        XCTAssertNotEqual(StickFigure.Pose.still(for: .pointingUp), StickFigure.Pose())
        let bow = StickFigure.Pose.still(for: .bowing)
        XCTAssertGreaterThan(bow.headDrop, 7)
        XCTAssertLessThan(bow.eyeHeight, StickFigure.openEyeHeight)
        XCTAssertEqual(StickFigure.Pose.bowing(at: 0).headDrop, 0)
    }
}
