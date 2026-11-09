import AVFoundation

/// 方塊 M3：上傳前把一段 WAV 壓成 AAC（S4-2）。5 分鐘的 16 kHz 單聲道 WAV 約 9.6 MB，壓成 32 kbps 約 1.2 MB；
/// 一小時約 14 MB，走路用行動網路也吃得消。OpenAI 轉錄收 m4a。
/// 壓不了（編碼器不在、空間不夠）就回 nil，呼叫端照送 WAV：多花流量，不會少字。
enum AudioCompressor {
    static let bitRate = 32000
    static let framesPerRead: AVAudioFrameCount = 16000

    /// K4 留存的 m4a 要重新轉錄時：解回 16 kHz 單聲道 WAV，切段那套只認 WAV。
    /// 先解到 `.part`，解完才換名：解到一半 App 被殺，不會留下半個 WAV 被當成完整的錄音。
    static func decodeToWAV(_ m4a: URL, to wav: URL) throws {
        let partial = wav.appendingPathExtension("part")
        defer { try? FileManager.default.removeItem(at: partial) }
        try decode(m4a, to: partial)
        try FileManager.default.moveItem(at: partial, to: wav)
    }

    private static func decode(_ m4a: URL, to wav: URL) throws {
        let source = try AVAudioFile(forReading: m4a)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: source.processingFormat,
            frameCapacity: framesPerRead
        ) else {
            throw CocoaError(.fileReadUnknown)
        }
        var writer = try WAVFileWriter(creatingAt: wav)
        while source.framePosition < source.length {
            try source.read(into: buffer)
            guard buffer.frameLength > 0, let channel = buffer.floatChannelData?[0] else {
                break
            }
            var pcm = Data(capacity: Int(buffer.frameLength) * 2)
            for index in 0 ..< Int(buffer.frameLength) {
                let clipped = max(-1, min(1, channel[index]))
                var sample = Int16(clipped * Float(Int16.max)).littleEndian
                withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
            }
            try writer.append(pcm: pcm)
        }
        try writer.finish()
    }

    static func m4a(fromWAV wav: Data) -> Data? {
        let directory = FileManager.default.temporaryDirectory
        let input = directory.appending(path: UUID().uuidString).appendingPathExtension("wav")
        let output = directory.appending(path: UUID().uuidString).appendingPathExtension("m4a")
        // 暫存檔裡是講過的話，用完就刪，不管成功失敗。
        defer {
            try? FileManager.default.removeItem(at: input)
            try? FileManager.default.removeItem(at: output)
        }
        do {
            try wav.write(to: input, options: .completeFileProtectionUntilFirstUserAuthentication)
            try encode(input, to: output)
            return try Data(contentsOf: output)
        } catch {
            DiagnosticLog.shared.record("壓縮失敗，改送 WAV：\(type(of: error))")
            return nil
        }
    }

    /// 寫完這個函式、`target` 被釋放，m4a 才算收好尾，之後才能讀。K4 留存錄音也直接用這個（檔對檔）。
    static func encode(_ input: URL, to output: URL) throws {
        let source = try AVAudioFile(forReading: input)
        let format = source.processingFormat
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: source.fileFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: bitRate,
        ]
        let target = try AVAudioFile(
            forWriting: output,
            settings: settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerRead) else {
            throw CocoaError(.fileWriteUnknown)
        }
        while source.framePosition < source.length {
            try source.read(into: buffer)
            guard buffer.frameLength > 0 else {
                break
            }
            try target.write(from: buffer)
        }
    }
}
