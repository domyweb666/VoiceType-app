import AVFoundation
import Foundation
import Observation

/// 方塊 M1：開始、停止、計時、音量；邊錄邊寫 WAV（C1），鎖屏繼續、被打斷不自動續錄（C3）。
/// 畫面只讀 `isRecording`、`isInterrupted`、`elapsedSeconds`、`level`、`levels`，不碰引擎。
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
    /// 錄音檔的保護等級。用「第一次解鎖後可用」：鎖屏時還在錄（C3），檔案要寫得進去（安全標準二）。
    static let fileProtection = FileProtectionType.completeUntilFirstUserAuthentication
    /// 轉換器輸出緩衝多留幾個 frame，取樣率換算有小數時不會不夠。
    private static let converterHeadroomFrames: AVAudioFrameCount = 16
    /// RMS 到這個值就當講話很大聲（柱子頂到底）。手感參數表沒給，標「待調」。
    private static let loudSpeechRMS = 0.25

    private(set) var isRecording = false
    /// 來電等中斷時 true：系統已把收音暫停，檔案與已錄的都在；等使用者按「繼續錄」或「停止」。
    private(set) var isInterrupted = false
    private(set) var elapsedSeconds: Double = 0
    /// 最近一段的音量，0 到 1。
    private(set) var level: Double = 0
    private(set) var levels: [Double] = Array(repeating: 0, count: Recorder.levelHistoryCount)

    private let engine = AVAudioEngine()
    @ObservationIgnored private var converter: AVAudioConverter?
    @ObservationIgnored private var writer: WAVFileWriter?
    /// 音訊執行緒寫不進去或轉不過去時記一筆，停止時報出來，不在回呼裡默默吞掉。
    @ObservationIgnored private var hasWriteFailure = false
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    private let fileManager = FileManager.default

    deinit {
        stopObservingInterruptions()
    }

    /// 問權限（第一次會跳系統框）、開收音、開始寫檔。失敗就拋，什麼都不留。
    @MainActor
    func start() async throws {
        guard !isRecording else {
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            throw Failure.microphoneDenied
        }
        try activateAudioSession()
        do {
            try startEngine()
        } catch {
            // 起不來就把剛開的東西全收掉：空檔不留（它從沒裝過資料，刪了不違反「存好才准刪」）。
            abandonStart()
            throw error
        }
        isRecording = true
        observeInterruptions()
    }

    /// 中斷結束後由使用者決定續錄（片 C3）。引擎已被系統停掉，tap 還在，重開就接著寫同一個檔。
    @MainActor
    func resume() throws {
        guard isRecording, isInterrupted else {
            throw Failure.notRecording
        }
        try activateAudioSession()
        do {
            try engine.start()
        } catch {
            throw Failure.inputUnavailable
        }
        isInterrupted = false
    }

    private func startEngine() throws {
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

        let fileURL = try Self.inProgressDirectoryURL().appending(path: Self.fileName())
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
            throw Failure.inputUnavailable
        }
    }

    private func abandonStart() {
        stopObservingInterruptions()
        converter = nil
        if let writer {
            try? fileManager.removeItem(at: writer.url)
        }
        writer = nil
        // 關不掉音訊工作階段不影響任何資料，所以不當錯誤。
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// 停收音、補檔頭，回錄好的檔在哪。呼叫端負責搬去待轉錄。
    @MainActor
    func stop() throws -> URL {
        guard isRecording else {
            throw Failure.notRecording
        }
        // 先拆 tap、停引擎，之後才拿 writer 的副本：不然最後一段還在寫，檔頭會少算它。
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        stopObservingInterruptions()
        isRecording = false
        isInterrupted = false
        guard let writer else {
            throw Failure.notRecording
        }
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

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(AudioInterruption(userInfo: notification.userInfo))
        }
    }

    private func stopObservingInterruptions() {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
    }

    /// 開始中斷：系統已經把引擎停了，我們只記下來讓面板換字。結束時不自動續錄，等使用者按。
    private func handleInterruption(_ kind: AudioInterruption?) {
        guard isRecording, let kind else {
            return
        }
        if kind == .began {
            isInterrupted = true
        }
    }
}

extension Recorder {
    /// 錄音中的檔先放這裡（救回檔的家，C4 在重開時來撿）；停止後呼叫端搬去待轉錄。
    static func inProgressDirectoryURL() throws -> URL {
        let fileManager = FileManager.default
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
            attributes: [.protectionKey: fileProtection]
        )
        return directory
    }
}

/// 收音的細節：音訊工作階段、目標格式、檔名、音訊執行緒的轉檔與音量。
private extension Recorder {
    func activateAudioSession() throws {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            throw Failure.audioSessionFailed
        }
    }

    static func targetFormat() throws -> AVAudioFormat {
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

    static func fileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date()) + ".wav"
    }

    /// 在音訊執行緒跑：轉成 16 kHz Int16、落地、算音量，再把數字丟回主執行緒給畫面。
    func handle(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let converter else {
            return
        }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        let capacity = frames + Self.converterHeadroomFrames
        let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity)
        guard let converted = output else {
            hasWriteFailure = true
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
            hasWriteFailure = true
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

    func publish(level: Double, elapsed: Double) {
        self.level = level
        elapsedSeconds = elapsed
        levels.removeFirst()
        levels.append(level)
    }

    /// RMS 換成 0 到 1；到 loudSpeechRMS 就截掉，柱子才不會老是貼頂或貼底。
    static func level(of samples: UnsafeBufferPointer<Int16>) -> Double {
        guard !samples.isEmpty else {
            return 0
        }
        var sum: Double = 0
        for sample in samples {
            let normalized = Double(sample) / Double(Int16.max)
            sum += normalized * normalized
        }
        let rms = (sum / Double(samples.count)).squareRoot()
        return min(rms / loudSpeechRMS, 1)
    }
}
