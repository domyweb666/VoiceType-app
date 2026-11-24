@testable import MiSay
import XCTest

/// 捷徑、控制中心按下「開始錄音」的那個請求：什麼時候開、什麼時候留著、什麼時候丟。
@MainActor
final class RecordingLauncherTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func take(
        _ launcher: RecordingLauncher,
        isRecording: Bool = false,
        isPanelOpening: Bool = false,
        after seconds: TimeInterval = 0
    ) -> RecordingLauncher.Request? {
        launcher.take(
            isRecording: isRecording,
            isPanelOpening: isPanelOpening,
            now: start.addingTimeInterval(seconds)
        )
    }

    func test開錄請求沒事擋著就馬上開而且只開一次() {
        let launcher = RecordingLauncher()
        XCTAssertNil(take(launcher))
        launcher.ask(.new, now: start)
        XCTAssertTrue(launcher.canStart(isRecording: false, now: start))
        XCTAssertEqual(take(launcher), .new)
        XCTAssertNil(take(launcher))
    }

    func test開錄請求正在錄就丟掉() {
        let launcher = RecordingLauncher()
        launcher.ask(.new, now: start)
        XCTAssertFalse(launcher.canStart(isRecording: true, now: start))
        XCTAssertNil(take(launcher, isRecording: true))
        XCTAssertNil(launcher.request)
        XCTAssertNil(take(launcher), "錄完不准又開一段")
    }

    func test開錄請求面板開著先留著收掉才開() {
        let launcher = RecordingLauncher()
        let panelID = UUID()
        launcher.panelOpened(panelID)
        launcher.panelOpened(panelID)
        launcher.ask(.new, now: start)
        XCTAssertNil(take(launcher, after: 10))
        XCTAssertFalse(launcher.canStart(isRecording: false, now: start))
        XCTAssertEqual(launcher.request, .new, "不准丟")

        launcher.panelClosed(panelID)
        XCTAssertEqual(take(launcher, after: 20), .new)
    }

    func test開錄請求面板正要升起也先留著() {
        let launcher = RecordingLauncher()
        launcher.ask(.new, now: start)
        XCTAssertNil(take(launcher, isPanelOpening: true))
        XCTAssertEqual(launcher.request, .new)
        launcher.forgetRequest()
        XCTAssertNil(take(launcher), "那次開錄了，留著的就不要了")
    }

    func test開錄請求留超過期限就不開() {
        let launcher = RecordingLauncher()
        let panelID = UUID()
        launcher.panelOpened(panelID)
        launcher.ask(.new, now: start)
        launcher.panelClosed(panelID)
        let late = RecordingLauncher.keepSeconds + 1
        XCTAssertFalse(launcher.canStart(
            isRecording: false,
            now: start.addingTimeInterval(late)
        ))
        XCTAssertNil(take(launcher, after: late))
        XCTAssertNil(launcher.request)
    }

    func test開錄請求留著時又按一次從新的算期限() {
        let launcher = RecordingLauncher()
        let panelID = UUID()
        launcher.panelOpened(panelID)
        launcher.ask(.new, now: start)
        launcher.ask(.new, now: start.addingTimeInterval(100))
        launcher.panelClosed(panelID)
        XCTAssertEqual(take(launcher, after: 200), .new)
    }
}
