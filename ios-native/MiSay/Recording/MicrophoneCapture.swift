import AVFoundation
import Foundation

/// 方塊 M1 的收音：麥克風 → 16 kHz Int16 → 同一個 WAV 檔。一段錄音一個實例，中間可以接回很多次。
/// 每次 `connect()` 都整組新建（新引擎、新接頭）：接回時硬體格式可能變了，
/// 舊接頭也可能接回了卻沒聲音（Apple 論壇 thread 805735）。
final class MicrophoneCapture {
    /// 轉換器輸出緩衝多留幾個 frame，取樣率換算有小數時不會不夠。
    private static let converterHeadroomFrames: AVAudioFrameCount = 16
    /// RMS 到這個值就當講話很大聲（柱子頂到底）。手感參數表沒給，標「待調」。
    private static let loudSpeechRMS = 0.25

    let url: URL
    /// 在收音執行緒叫：音量 0 到 1、寫到目前的秒數。
    private let onSamples: (Double, Double) -> Void
    /// 在主執行緒叫：引擎因為硬體變動自己停了。
    private let onEngineStopped: () -> Void
    private let targetFormat: AVAudioFormat

    /// 下面三個收音執行緒與主執行緒都會碰，一律在鎖裡。
    private let lock = NSLock()
    private var writer: WAVFileWriter
    private var converter: AVAudioConverter?
    private var isWriteFailed = false

    private var engine: AVAudioEngine?
    private var configurationObserver: NSObjectProtocol?

    /// 建新檔。還沒開始收音，要收音叫 `connect()`。
    init(
        creatingAt url: URL,
        onSamples: @escaping (Double, Double) -> Void,
        onEngineStopped: @escaping () -> Void
    ) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(WAVFileWriter.sampleRate),
            channels: AVAudioChannelCount(WAVFileWriter.channelCount),
            interleaved: true
        ) else {
            throw Recorder.Failure.inputUnavailable
        }
        targetFormat = format
        self.url = url
        self.onSamples = onSamples
        self.onEngineStopped = onEngineStopped
        do {
            writer = try WAVFileWriter(creatingAt: url)
        } catch {
            throw Recorder.Failure.fileFailed
        }
    }

    /// 寫到現在的資料量；`Recorder` 用它判斷錄音有沒有在動。
    var writtenByteCount: UInt32 {
        lock.withLock { writer.dataByteCount }
    }

    /// 寫不進去（多半是空間滿了）。接回時歸零。
    var hasWriteFailure: Bool {
        lock.withLock { isWriteFailed }
    }

    /// 整組新建再開始收音；已經接著的會先拆掉。音訊工作階段要先開好。
    func connect() throws {
        disconnect()
        lock.withLock {
            isWriteFailed = false
            // 舊轉換器可能已經壞了（音訊服務重置之後）；每次接回都換新的。
            converter = nil
        }
        let newEngine = AVAudioEngine()
        let input = newEngine.inputNode
        // 通話中或沒有麥克風時格式是 0；這時裝接頭會丟 Objective-C 例外，整個 App 當掉，先擋。
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw Recorder.Failure.inputUnavailable
        }
        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate / Recorder.levelsPerSecond)
        let tap: AVAudioNodeTapBlock = { [weak self] buffer, _ in
            self?.handle(buffer)
        }
        // format 傳 nil：用接頭當下的格式，硬體剛好在換也不會因為對不上當掉。
        input.installTap(onBus: 0, bufferSize: bufferSize, format: nil, block: tap)
        do {
            try newEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            DiagnosticLog.shared.record("引擎開不起來 \((error as NSError).code)")
            throw Recorder.Failure.inputUnavailable
        }
        engine = newEngine
        observeConfigurationChange(of: newEngine)
        DiagnosticLog.shared.record(
            "收音接上 \(Int(inputFormat.sampleRate)) Hz \(inputFormat.channelCount) 聲道"
        )
    }

    /// 停收音、拆接頭。檔案還開著，可以再 `connect()`。
    func disconnect() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        guard let engine else {
            return
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }

    /// 停收音、補檔頭。之後這個實例不能再用。
    func finish() throws {
        disconnect()
        do {
            try lock.withLock { try writer.finish() }
        } catch {
            throw Recorder.Failure.fileFailed
        }
    }

    /// 起不來時把空檔丟掉（它從沒裝過資料，刪了不違反「存好才准刪」）。
    func discardEmptyFile() {
        disconnect()
        // 刪不掉只是留一個空檔，重開時撿回會把它丟掉。
        try? FileManager.default.removeItem(at: url)
    }

    /// 在收音執行緒跑：轉成 16 kHz Int16、落地、算音量。不是 private：單元測試直接餵不同格式的聲音。
    func handle(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        // 轉不過去丟這一段；一直轉不過去檔案就不會長，`Recorder` 會當成卡住處理。
        guard let converted = convert(buffer), let channels = converted.int16ChannelData else {
            return
        }
        let samples = UnsafeBufferPointer(start: channels[0], count: Int(converted.frameLength))
        do {
            try writer.append(pcm: Data(buffer: samples))
        } catch {
            isWriteFailed = true
        }
        onSamples(Self.level(of: samples), writer.elapsedSeconds)
    }

    /// 格式變了就換新的轉換器，檔案永遠是同一個 16 kHz 單聲道。
    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let converter else {
            return nil
        }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        let capacity = frames + Self.converterHeadroomFrames
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return nil
        }
        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        return status == .error ? nil : output
    }

    /// queue 傳 nil、再丟回主執行緒：Apple 文件說不能在這個通知的處理裡拆引擎，會死結。
    private func observeConfigurationChange(of observed: AVAudioEngine) {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: observed,
            queue: nil
        ) { [weak self, weak observed] _ in
            DispatchQueue.main.async { [weak self, weak observed] in
                self?.handleConfigurationChange(of: observed)
            }
        }
    }

    /// 排隊期間可能已經換了新引擎；舊引擎的通知不算。
    private func handleConfigurationChange(of changed: AVAudioEngine?) {
        guard let changed, changed === engine else {
            return
        }
        onEngineStopped()
    }

    /// RMS 換成 0 到 1；到 loudSpeechRMS 就截掉，柱子才不會老是貼頂或貼底。
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
        return min(rms / loudSpeechRMS, 1)
    }
}
