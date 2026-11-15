@testable import MiSay
import XCTest

/// 動 1、動 2（2026-11-15）：戴玉米頭套的火柴人。畫面長相要真機看，這裡只驗算得出來的：眨眼的時間、晃動的幅度、關節往哪邊走。
final class StickFigureTests: XCTestCase {
    func test待機大部分時間眼睛是睜開的() {
        XCTAssertEqual(StickFigure.Pose.idle(at: 0).eyeHeight, StickFigure.openEyeHeight)
        XCTAssertEqual(StickFigure.Pose.idle(at: 1.8).eyeHeight, StickFigure.openEyeHeight)
    }

    func test每一輪最後那一下閉眼再睜開() {
        let justBeforeNextRound = StickFigure.Pose.blinkPeriod - StickFigure.Pose.blinkLength / 2
        XCTAssertEqual(
            StickFigure.Pose.idle(at: justBeforeNextRound).eyeHeight,
            StickFigure.closedEyeHeight
        )
        XCTAssertEqual(
            StickFigure.Pose.idle(at: StickFigure.Pose.blinkPeriod + 0.5).eyeHeight,
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

    func test思考是右手托下巴頭上有泡泡() {
        let pose = StickFigure.Pose.thinking(at: 2)
        XCTAssertEqual(pose.thoughtSeconds, 2)
        XCTAssertEqual(pose.mouth, .flat)
        XCTAssertNotEqual(pose.rightElbow, StickFigure.Pose().rightElbow)
        XCTAssertNil(StickFigure.Pose.idle(at: 2).thoughtSeconds)
    }

    func test慶祝頭兩下在空中之後落地站好() {
        let period = StickFigure.Pose.cheerPeriod
        let firstJump = StickFigure.Pose.cheering(at: period * 0.4)
        XCTAssertLessThan(firstJump.jump, -20)
        XCTAssertEqual(firstJump.squash, 0)
        let secondJump = StickFigure.Pose.cheering(at: period * 1.4)
        XCTAssertLessThan(secondJump.jump, -20)
        let landing = StickFigure.Pose.cheering(at: period * 0.9)
        XCTAssertEqual(landing.jump, 0)
        XCTAssertGreaterThan(landing.squash, 0)
        for seconds in stride(from: period * 2, through: 30, by: 0.41) {
            let pose = StickFigure.Pose.cheering(at: seconds)
            XCTAssertEqual(pose.jump, 0)
            XCTAssertEqual(pose.squash, 0)
            XCTAssertTrue(pose.hasHappyEyes)
            XCTAssertEqual(pose.leftKnee, 0, accuracy: 0.001)
        }
    }

    func test跳完一秒後手不再抖() {
        let later = StickFigure.Pose.cheering(at: StickFigure.Pose.cheerPeriod * 2 + 1)
        XCTAssertEqual(later.leftElbow, -62, accuracy: 0.001)
        XCTAssertEqual(later.rightElbow, 62, accuracy: 0.001)
    }

    func test不動的那一張看得出是哪個動作() {
        XCTAssertEqual(StickFigure.Pose.still(for: .idle), StickFigure.Pose())
        XCTAssertNotNil(StickFigure.Pose.still(for: .thinking).thoughtSeconds)
        let cheer = StickFigure.Pose.still(for: .cheering)
        XCTAssertEqual(cheer.jump, 0)
        XCTAssertEqual(cheer.headDrop, 0)
        XCTAssertEqual(cheer.leftShoulder, -105)
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
