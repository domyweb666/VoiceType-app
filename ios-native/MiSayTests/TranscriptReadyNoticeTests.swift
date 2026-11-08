@testable import MiSay
import XCTest

/// 片 S4-3：「文字稿好了」通知的字。鎖定畫面看得到，只講長度，不放講過的話。
final class TranscriptReadyNoticeTests: XCTestCase {
    func test通知只講長度() {
        XCTAssertEqual(TranscriptReadyNotice.body(durationSeconds: 20), "剛才那段整理好了，點開看。")
        XCTAssertEqual(TranscriptReadyNotice.body(durationSeconds: 61 * 60), "61 分鐘那段整理好了，點開看。")
    }
}
