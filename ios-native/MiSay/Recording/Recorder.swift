import AVFoundation
import Foundation
import Observation

/// 方塊 M1：一台最陽春的錄音機。開始、停止、計時、音量；邊錄邊寫 WAV。
/// 鎖屏繼續、中斷處理是 C3；救回是 C4；權限被拒的畫面是 C2。
/// 畫面只讀 `isRecording`、`elapsedSeconds`、`level`、`levels`，不碰引擎。
@Observable
final class Recorder {
    enum Failure: Error, Equatable {
        case microphoneDenied
        case audioSessionFailed
        case inputUnavailable
        case fileFailed
        case notRecording
    }

    /// 波形每秒更新次數（手感參數表：約 20 次）。
    static let levelsPerSecond = Token.Motion.waveformHz
    /// 畫面上柱子的根數；滿了從左邊掉出去。
    static let levelHistoryCount = 40

    private(set) var isRecording = false
    private(set) var elapsedSeconds: Double = 0
    /// 最近一段的音量，0 到 1。
    private(set) var level: Double = 0
    private(set) var levels: [Double] = Array(repeating: 0, count: Recorder.levelHistoryCount)

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var writer: WAVFileWriter?
    /// 音訊執行緒寫不進去時記一筆，停止時才報，不在回呼裡默默吞掉。
    private var hasWriteFailure = false
    private let fileManager = FileManager.default

    /// 錄音中的檔先放這裡（救回檔的家，C4 會來撿）；停止後呼叫端搬去待轉錄。
    func inProgressDirectoryURL() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(path: "Recording", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: PendingRecordings.fileProtection]
        )
        return directory
    }

    /// 問權限（第一次會跳系統框）、開收音、開始寫檔。失敗就拋，什麼都不留。
    @MainActor
    func start() async throws {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw Failure.microphoneDenied
        }
        try activateAudioSession()
        let targetFormat = try Self.targetFormat()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            throw Failure.inputUnavailable
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw Failure.inputUnavailable
        }
        self.converter = converter
        hasWriteFailure = false

        let fileURL = try inProgressDirectoryURL().appending(path: Self.fileName())
        do {
            writer = try WAVFileWriter(creatingAt: fileURL)
        } catch {
            throw Failure.fileFailed
        }

        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate / Self.levelsPerSecond)
        let tap: AVAudioNodeTapBlock = { [weak self] buffer, _ in
            self?.handle(buffer, targetFormat: targetFormat)
        }
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat, block: tap)
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            writer = nil
            throw Failure.inputUnavailable
        }
        isRecording = true
    }

    /// 停收音、補檔頭，回錄好的檔在哪。呼叫端負責搬去待轉錄。
    @MainActor
    func stop() throws -> URL {
        guard isRecording, let writer else {
            throw Failure.notRecording
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        self.writer = nil
        do {
            try writer.finish()
        } catch {
            throw Failure.fileFailed
        }
        // 關不掉音訊工作階段不影響已經寫好的檔，所以不當錯誤。
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard !hasWriteFailure else {
            throw Failure.fileFailed
        }
        return writer.url
    }

    private func activateAudioSession() throws {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            throw Failure.audioSessionFailed
        }
    }

    private static func targetFormat() throws -> AVAudioFormat {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(WAVFileWriter.sampleRate),
            channels: AVAudioChannelCount(WAVFileWriter.channelCount),
            interleaved: true
        ) else {
            throw Failure.inputUnavailable
        }
        return format
    }

    private static func fileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date()) + ".wav"
    }

    /// 在音訊執行緒跑：轉成 16 kHz Int16、落地、算音量，再把數字丟回主執行緒給畫面。
    private func handle(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let converter else {
            return
        }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }
        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let channels = converted.int16ChannelData else {
            return
        }
        let samples = UnsafeBufferPointer(start: channels[0], count: Int(converted.frameLength))
        let pcm = Data(buffer: samples)
        let sampleLevel = Self.level(of: samples)
        var elapsed = elapsedSeconds
        do {
            try writer?.append(pcm: pcm)
            elapsed = writer?.elapsedSeconds ?? elapsed
        } catch {
            // 寫不進去這一段就丟這一段，下一段再試；停止時用 hasWriteFailure 報出來。
            hasWriteFailure = true
        }
        DispatchQueue.main.async { [weak self] in
            self?.publish(level: sampleLevel, elapsed: elapsed)
        }
    }

    private func publish(level: Double, elapsed: Double) {
        self.level = level
        elapsedSeconds = elapsed
        levels.removeFirst()
        levels.append(level)
    }

    /// RMS 換成 0 到 1；0.25 左右就算講話很大聲，再往上截掉，柱子才不會老是貼頂或貼底。
    private static func level(of samples: UnsafeBufferPointer<Int16>) -> Double {
        guard !samples.isEmpty else {
            return 0
        }
        var sum: Double = 0
        for sample in samples {
            let normalized = Double(sample) / Double(Int16.max)
            sum += normalized * normalized
        }
        let rms = (sum / Double(samples.count)).squareRoot()
        return min(rms * 4, 1)
    }
}
