@testable import MiSay
import XCTest

/// 片 C1：面板上的計時字。畫面本身只有米在真機看得到。
final class RecordingSheetViewTests: XCTestCase {
    func test錄音計時顯示成分秒而且超過一小時加小時() {
        XCTAssertEqual(RecordingSheetView.formatElapsed(0), "00:00")
        XCTAssertEqual(RecordingSheetView.formatElapsed(137.6), "02:17")
        XCTAssertEqual(RecordingSheetView.formatElapsed(3737), "1:02:17")
    }
}
