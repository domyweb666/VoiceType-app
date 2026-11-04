import AVFoundation

/// 系統的中斷通知翻成三種：開始（來電、Siri）、結束可續、結束不可續（片 C3）。
/// 兩種「結束」都試著接回（2026-11-04 米點頭）：不可續時系統多半會拒絕，拒絕了 `Recorder` 會再試、手機會響。
enum AudioInterruption: Equatable {
    case began
    case endedCanResume
    case endedCannotResume

    init?(userInfo: [AnyHashable: Any]?) {
        guard let rawType = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return nil
        }
        switch type {
        case .began:
            self = .began
        case .ended:
            let rawOptions = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            self = options.contains(.shouldResume) ? .endedCanResume : .endedCannotResume
        @unknown default:
            return nil
        }
    }
}
