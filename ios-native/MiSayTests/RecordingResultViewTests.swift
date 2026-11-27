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

    func test在編輯頁錄的_講清楚字在哪() {
        XCTAssertEqual(
            RecordingResultView.returnedMessage(isMerged: true, isWaiting: false),
            "剛才錄的已經放回文稿裡。"
        )
        XCTAssertEqual(
            RecordingResultView.returnedMessage(isMerged: false, isWaiting: true),
            "整理好了，等一下會放回文稿裡。"
        )
        XCTAssertEqual(
            RecordingResultView.returnedMessage(isMerged: false, isWaiting: false),
            "放不回原本那篇，另外存成一篇，在文字稿清單裡。"
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

    func test整理中進度條轉到第幾段前面算轉好() {
        let name = "20261101-120000.wav"
        let second = TranscriptionQueue.Activity.transcribing(
            recording: name,
            segment: 2,
            totalSegments: 3
        )
        XCTAssertEqual(
            RecordingResultView.transcriptionCells(for: second, recording: name, knownTotal: 1),
            [.done, .working, .waiting]
        )
        XCTAssertEqual(RecordingResultView.segmentCount(for: second, recording: name), 3)
        XCTAssertNil(RecordingResultView.segmentCount(for: second, recording: "other.wav"))

        // 進到潤飾時不再帶段數，沿用記下的格數、全部算轉好。
        let polishing = TranscriptionQueue.Activity.polishing(recording: name)
        XCTAssertEqual(
            RecordingResultView.transcriptionCells(for: polishing, recording: name, knownTotal: 3),
            [.done, .done, .done]
        )
        XCTAssertTrue(RecordingResultView.isPolishing(polishing, recording: name))
        XCTAssertFalse(RecordingResultView.isPolishing(second, recording: name))
        XCTAssertEqual(
            RecordingResultView.transcriptionCells(for: .idle, recording: name, knownTotal: 1),
            [.waiting]
        )
    }
}
