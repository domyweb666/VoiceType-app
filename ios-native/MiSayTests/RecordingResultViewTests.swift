@testable import MiSay
import XCTest

/// 片 D6：錄音面板後半段的文案對應。畫面本身、自動複製、觸覺只有米在真機看得到。
final class RecordingResultViewTests: XCTestCase {
    func test整理失敗沒網路說連上後會自動整理而且不給去設定() {
        XCTAssertEqual(
            RecordingResultView.failedStatus(for: .transport(.notConnectedToInternet)),
            .transcriptionFailed(reason: "現在沒有網路，連上後會自動整理。", needsNewKey: false)
        )
        XCTAssertEqual(
            RecordingResultView.failedStatus(for: .timedOut),
            .transcriptionFailed(reason: "現在沒有網路，連上後會自動整理。", needsNewKey: false)
        )
    }

    func test整理失敗金鑰沒有用給去設定() {
        XCTAssertEqual(
            RecordingResultView.failedStatus(for: .invalidAPIKey(statusCode: 401)),
            .transcriptionFailed(reason: "金鑰沒有用，到設定換一把。", needsNewKey: true)
        )
    }

    func test整理中只有這一筆切成兩段以上才說第幾段() {
        let name = "20261101-120000.wav"
        let second = TranscriptionQueue.Activity.transcribing(
            recording: name,
            segment: 2,
            totalSegments: 3
        )
        XCTAssertEqual(RecordingResultView.segmentText(for: second, recording: name), "第 2／3 段")

        let single = TranscriptionQueue.Activity.transcribing(
            recording: name,
            segment: 1,
            totalSegments: 1
        )
        XCTAssertNil(RecordingResultView.segmentText(for: single, recording: name))
        XCTAssertNil(RecordingResultView.segmentText(for: second, recording: "other.wav"))
        XCTAssertNil(RecordingResultView.segmentText(for: .idle, recording: name))
    }
}
