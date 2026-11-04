import Foundation

extension Recorder {
    /// 波形每秒更新次數（手感參數表：約 20 次）。
    static let levelsPerSecond = Token.Motion.waveformHz
    /// 畫面上柱子的根數；滿了從左邊掉出去。
    static let levelHistoryCount = 40
    /// 錄音檔的保護等級。用「第一次解鎖後可用」：鎖屏時還在錄（C3），檔案要寫得進去（安全標準二）。
    static let fileProtection = FileProtectionType.completeUntilFirstUserAuthentication

    enum Failure: Error, Equatable {
        case microphoneDenied
        case audioSessionFailed
        case inputUnavailable
        case fileFailed
        case notRecording
        case notEnoughSpace
    }

    /// 為什麼現在沒在收音。已錄到的都在檔案裡。
    enum PauseReason: Equatable {
        /// 來電、鬧鐘、Siri：結束後自己接回。
        case interrupted
        /// 硬體變動或卡住，還沒接回來。
        case lostInput
        /// 空間滿了：不自己接回，等使用者清出空間按繼續錄。
        case outOfSpace
    }
}
