import AVFoundation
@testable import MiSay
import XCTest

/// 片 C3：中斷通知的判讀與面板上唸給人聽的秒數。真的來電只有真機驗得到。
final class RecorderTests: XCTestCase {
    func test錄音中斷通知分成開始與結束() {
        let began: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue,
        ]
        XCTAssertEqual(AudioInterruption(userInfo: began), .began)

        let shouldResume = AVAudioSession.InterruptionOptions.shouldResume.rawValue
        let endedResume: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: shouldResume,
        ]
        XCTAssertEqual(AudioInterruption(userInfo: endedResume), .endedCanResume)

        let endedNoResume: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
        ]
        XCTAssertEqual(AudioInterruption(userInfo: endedNoResume), .endedCannotResume)
        XCTAssertNil(AudioInterruption(userInfo: nil))
    }

    func test錄音秒數唸成分與秒() {
        XCTAssertEqual(RecordingSheetView.formatSpoken(137), "2 分 17 秒")
        XCTAssertEqual(RecordingSheetView.formatSpoken(17), "17 秒")
        XCTAssertEqual(RecordingSheetView.formatSpoken(3737), "1 小時 2 分 17 秒")
    }
}
