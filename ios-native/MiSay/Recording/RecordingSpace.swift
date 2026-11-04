import Foundation

/// 方塊 M1：手機空間夠不夠錄。一小時 115 MB；空間滿了聲音會被丟掉，要在那之前講。
enum RecordingSpace {
    enum Verdict: Equatable {
        case plenty
        case low(minutesLeft: Int)
        case full
    }

    static let warnBelowBytes: Int64 = 300_000_000
    static let stopBelowBytes: Int64 = 100_000_000

    /// 讀不到剩多少時當夠：不因為讀不到就不讓錄，真的寫不進去還有 `MicrophoneCapture.hasWriteFailure`。
    static func verdict(availableBytes: Int64?) -> Verdict {
        guard let availableBytes, availableBytes < warnBelowBytes else {
            return .plenty
        }
        guard availableBytes >= stopBelowBytes else {
            return .full
        }
        let bytesPerFrame = WAVFileWriter.channelCount * WAVFileWriter.bitsPerSample / 8
        let bytesPerMinute = Int64(WAVFileWriter.sampleRate * bytesPerFrame * 60)
        return .low(minutesLeft: Int((availableBytes - stopBelowBytes) / bytesPerMinute))
    }

    static func availableBytes() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]
        // 讀不到不是錯：見 `verdict`。
        guard let values = try? home.resourceValues(forKeys: keys) else {
            return nil
        }
        // 兩個數字取大的：讀錯一次就把錄音停掉，代價比少警告一次大得多。
        let plain = values.volumeAvailableCapacity.map { Int64($0) }
        return [plain, values.volumeAvailableCapacityForImportantUsage].compactMap { $0 }.max()
    }
}
