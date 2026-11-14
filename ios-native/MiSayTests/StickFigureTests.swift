@testable import MiSay
import XCTest

/// 動 1（2026-11-15）：戴玉米頭套的火柴人。畫面長相要真機看，這裡只驗算得出來的：眨眼的時間、晃動的幅度、關節往哪邊走。
final class StickFigureTests: XCTestCase {
    func test待機大部分時間眼睛是睜開的() {
        XCTAssertEqual(StickFigure.Pose.idle(at: 0).eyeHeight, StickFigure.openEyeHeight)
        XCTAssertEqual(StickFigure.Pose.idle(at: 1.8).eyeHeight, StickFigure.openEyeHeight)
    }

    func test每一輪最後那一下閉眼再睜開() {
        let justBeforeNextRound = StickFigure.blinkPeriod - StickFigure.blinkLength / 2
        XCTAssertEqual(
            StickFigure.Pose.idle(at: justBeforeNextRound).eyeHeight,
            StickFigure.closedEyeHeight
        )
        XCTAssertEqual(
            StickFigure.Pose.idle(at: StickFigure.blinkPeriod + 0.5).eyeHeight,
            StickFigure.openEyeHeight
        )
    }

    func test待機只晃身體不動手腳() {
        let standing = StickFigure.Pose()
        for seconds in stride(from: 0.0, through: 20, by: 0.37) {
            let pose = StickFigure.Pose.idle(at: seconds)
            XCTAssertEqual(pose.leftShoulder, standing.leftShoulder)
            XCTAssertEqual(pose.rightElbow, standing.rightElbow)
            XCTAssertEqual(pose.leftHip, standing.leftHip)
            XCTAssertEqual(pose.rightKnee, standing.rightKnee)
            XCTAssertLessThanOrEqual(abs(pose.lean), 2)
            XCTAssertLessThanOrEqual(abs(pose.headTilt), 2)
            XCTAssertLessThanOrEqual(abs(pose.headDrop), 2)
        }
    }

    func test零度往下九十度往右() {
        let origin = CGPoint(x: 10, y: 20)
        let down = StickFigure.point(from: origin, angle: 0, length: 50)
        XCTAssertEqual(down.x, 10, accuracy: 0.001)
        XCTAssertEqual(down.y, 70, accuracy: 0.001)
        let right = StickFigure.point(from: origin, angle: 90, length: 50)
        XCTAssertEqual(right.x, 60, accuracy: 0.001)
        XCTAssertEqual(right.y, 20, accuracy: 0.001)
        let upward = StickFigure.point(from: origin, angle: 180, length: 50)
        XCTAssertEqual(upward.x, 10, accuracy: 0.001)
        XCTAssertEqual(upward.y, -30, accuracy: 0.001)
    }
}
