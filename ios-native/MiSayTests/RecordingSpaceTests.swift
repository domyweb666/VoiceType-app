@testable import MiSay
import XCTest

/// 組塊 S 片 S4：空間夠不夠錄。真的把手機塞滿只有真機做得到，門檻這裡鎖死。
final class RecordingSpaceTests: XCTestCase {
    func test錄音空間足夠或讀不到都當夠() {
        XCTAssertEqual(RecordingSpace.verdict(availableBytes: 300_000_000), .plenty)
        XCTAssertEqual(RecordingSpace.verdict(availableBytes: nil), .plenty)
    }

    func test錄音空間快滿時算得出還能錄幾分鐘() {
        // 一分鐘 1.92 MB；能用的是扣掉 100 MB 保留之後的部分。
        XCTAssertEqual(
            RecordingSpace.verdict(availableBytes: 215_200_000),
            .low(minutesLeft: 60)
        )
        XCTAssertEqual(RecordingSpace.verdict(availableBytes: 100_000_000), .low(minutesLeft: 0))
    }

    func test錄音空間不到一百MB就不錄() {
        XCTAssertEqual(RecordingSpace.verdict(availableBytes: 99_999_999), .full)
        XCTAssertEqual(RecordingSpace.verdict(availableBytes: 0), .full)
    }
}
