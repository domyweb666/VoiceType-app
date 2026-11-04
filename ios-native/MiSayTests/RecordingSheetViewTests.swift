@testable import MiSay
import XCTest

/// 片 C1：面板上的計時字。畫面本身只有米在真機看得到。
final class RecordingSheetViewTests: XCTestCase {
    func test錄音計時顯示成分秒而且超過一小時加小時() {
        XCTAssertEqual(RecordingSheetView.formatElapsed(0), "00:00")
        XCTAssertEqual(RecordingSheetView.formatElapsed(137.6), "02:17")
        XCTAssertEqual(RecordingSheetView.formatElapsed(3737), "1:02:17")
    }

    func test錄音沒在收音時講發生什麼而且講已錄到的都在() {
        let saved = "已錄到的 2 分 17 秒 都在。"
        XCTAssertEqual(
            RecordingSheetView.pausedMessage(for: .interrupted, elapsed: 137),
            "被打斷了，結束後會自己接回去。\(saved)"
        )
        XCTAssertEqual(
            RecordingSheetView.pausedMessage(for: .lostInput, elapsed: 137),
            "收音斷了，正在接回去。\(saved)"
        )
        XCTAssertEqual(
            RecordingSheetView.pausedMessage(for: .outOfSpace, elapsed: 137),
            "手機空間快滿了，先停了。\(saved)清出空間可以按繼續錄。"
        )
    }

    func test錄音沒斷過不講斷過幾次() {
        XCTAssertNil(RecordingSheetView.gapText(for: CaptureWatch.Gaps()))
        XCTAssertEqual(
            RecordingSheetView.gapText(for: CaptureWatch.Gaps(times: 2, seconds: 80)),
            "中間斷過 2 次，共 1 分 20 秒。"
        )
        XCTAssertEqual(
            RecordingSheetView.gapText(for: CaptureWatch.Gaps(times: 1, seconds: 0.2)),
            "中間斷過 1 次，共 不到 1 秒。"
        )
    }
}
