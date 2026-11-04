@testable import MiSay
import XCTest

/// 組塊 S：錄音有沒有在動、什麼時候接回、什麼時候推通知。真的來電與換耳機只有真機驗得到，判斷邏輯這裡鎖死。
final class CaptureWatchTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func time(_ seconds: Double) -> Date {
        start.addingTimeInterval(seconds)
    }

    private func checkRunning(
        _ watch: inout CaptureWatch,
        bytes: UInt32,
        at seconds: Double
    ) -> CaptureWatch.Decision {
        watch.check(byteCount: bytes, isPaused: false, canReconnect: true, now: time(seconds))
    }

    func test錄音檔案一直長就不算卡住() {
        var watch = CaptureWatch(startedAt: start)
        for second in 1 ... 20 {
            let decision = checkRunning(&watch, bytes: UInt32(second) * 32000, at: Double(second))
            XCTAssertFalse(decision.isStalled)
        }
    }

    func test錄音檔案五秒沒長算卡住() {
        var watch = CaptureWatch(startedAt: start)
        XCTAssertFalse(checkRunning(&watch, bytes: 32000, at: 1).isStalled)
        XCTAssertFalse(checkRunning(&watch, bytes: 32000, at: 5).isStalled)
        XCTAssertTrue(checkRunning(&watch, bytes: 32000, at: 6).isStalled)
    }

    func test錄音打斷剛開始不馬上搶之後每十秒試接一次() {
        var watch = CaptureWatch(startedAt: start)
        watch.noteCaptureLost(at: time(100), byteCount: 0)
        var attempts: [Double] = []
        for second in stride(from: 101.0, through: 125.0, by: 1.0) {
            let decision = watch.check(
                byteCount: 0,
                isPaused: true,
                canReconnect: true,
                now: time(second)
            )
            if decision.shouldReconnect {
                attempts.append(second)
            }
        }
        XCTAssertEqual(attempts, [110, 120])
    }

    func test錄音空間滿時不自己接回() {
        var watch = CaptureWatch(startedAt: start)
        watch.noteCaptureLost(at: time(1), byteCount: 0)
        let decision = watch.check(
            byteCount: 0,
            isPaused: true,
            canReconnect: false,
            now: time(100)
        )
        XCTAssertFalse(decision.shouldReconnect)
    }

    func test錄音有新聲音才把通知往後推() {
        var watch = CaptureWatch(startedAt: start)
        XCTAssertFalse(checkRunning(&watch, bytes: 32000, at: 29).shouldPushBackAlarm)
        XCTAssertTrue(checkRunning(&watch, bytes: 64000, at: 30).shouldPushBackAlarm)
        XCTAssertFalse(checkRunning(&watch, bytes: 96000, at: 31).shouldPushBackAlarm)
    }

    func test錄音接上了卻沒聲音時通知不會被往後推() {
        var watch = CaptureWatch(startedAt: start)
        watch.noteCaptureLost(at: time(1), byteCount: 0)
        watch.noteConnected(at: time(40))
        // 接上之後檔案沒長：沒有新聲音，就算過了 30 秒也不推，時間到通知要響。
        XCTAssertFalse(checkRunning(&watch, bytes: 0, at: 41).shouldPushBackAlarm)
        XCTAssertTrue(checkRunning(&watch, bytes: 0, at: 45).isStalled)
    }

    func test錄音斷幾次共多久要等聲音回來才算() {
        var watch = CaptureWatch(startedAt: start)
        _ = checkRunning(&watch, bytes: 32000, at: 1)
        watch.noteCaptureLost(at: time(10), byteCount: 32000)
        watch.noteConnected(at: time(40))
        XCTAssertEqual(watch.gaps.times, 0, "接上了還沒聲音，不算回來")
        XCTAssertTrue(watch.isWaitingForSound)
        _ = checkRunning(&watch, bytes: 64000, at: 41)
        XCTAssertEqual(watch.gaps.times, 1)
        XCTAssertEqual(watch.gaps.seconds, 31, accuracy: 0.001)
        XCTAssertFalse(watch.isWaitingForSound)

        watch.noteCaptureLost(at: time(50), byteCount: 64000)
        watch.noteCaptureLost(at: time(55), byteCount: 64000)
        watch.noteConnected(at: time(60))
        _ = checkRunning(&watch, bytes: 96000, at: 61)
        XCTAssertEqual(watch.gaps.times, 2, "接回失敗又試一次，還是同一次斷")
        XCTAssertEqual(watch.gaps.seconds, 42, accuracy: 0.001)
    }

    func test錄音斷之前最後一秒的資料接回後不算新聲音() {
        var watch = CaptureWatch(startedAt: start)
        _ = checkRunning(&watch, bytes: 32000, at: 40)
        // 40.7 秒斷的時候已經寫到 54400，但 check 還沒看過。
        watch.noteCaptureLost(at: time(40.7), byteCount: 54400)
        watch.noteConnected(at: time(70))
        let decision = checkRunning(&watch, bytes: 54400, at: 71)
        XCTAssertFalse(decision.shouldPushBackAlarm, "接上了卻沒聲音，通知要照樣響")
        XCTAssertEqual(watch.gaps.times, 0)
    }

    func test錄音接上就斷連續太多次才慢下來() {
        var watch = CaptureWatch(startedAt: start)
        XCTAssertTrue(watch.allowsImmediateReconnect(at: time(1)), "第一下常見，馬上重接")
        watch.noteConnected(at: time(1))
        XCTAssertTrue(watch.allowsImmediateReconnect(at: time(2)))
        watch.noteConnected(at: time(2))
        XCTAssertFalse(watch.allowsImmediateReconnect(at: time(3)), "第三次連續彈跳，等定時重試")
        watch.noteConnected(at: time(13))
        XCTAssertTrue(watch.allowsImmediateReconnect(at: time(20)), "穩了一陣子，歸零")
    }

    func test錄音每三十秒看一次空間() {
        var watch = CaptureWatch(startedAt: start)
        XCTAssertFalse(checkRunning(&watch, bytes: 1, at: 29).shouldCheckSpace)
        XCTAssertTrue(checkRunning(&watch, bytes: 2, at: 30).shouldCheckSpace)
        XCTAssertFalse(checkRunning(&watch, bytes: 3, at: 31).shouldCheckSpace)
    }
}
