import AVFoundation

/// K7 匯入音檔：語音備忘錄、講座錄音、Podcast（m4a、mp3、wav…）轉成米說自己的 16 kHz 單聲道 WAV，
/// 放進待轉錄，之後照原本的切段、轉錄、潤飾走。原檔不動（從「檔案」選的）；從分享表單送進來的暫存副本用完就刪。
enum AudioImport {
    enum Failure: Error, Equatable {
        case cannotRead
        case cannotWrite
        case empty
    }

    static let framesPerRead: AVAudioFrameCount = 32768

    /// 回放進待轉錄之後的位置。先寫成 `.part` 再改名：寫到一半時自動續轉不會撿到半個檔。
    static func importAudio(from source: URL) throws -> URL {
        let isScoped = source.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                source.stopAccessingSecurityScopedResource()
            }
        }
        let name = "import-\(Recorder.newFileName())"
        let directory = try PendingRecordings().directoryURL()
        let partial = directory.appending(path: name + ".part")
        let destination = directory.appending(path: name)
        do {
            try convert(source, to: partial)
            try FileManager.default.moveItem(at: partial, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            throw error
        }
        // 分享表單「拷貝到米說」會先放進 Inbox，那份是給我們的副本，收好就刪。
        if source.path.contains("/Inbox/") {
            try? FileManager.default.removeItem(at: source)
        }
        return destination
    }

    private static func convert(_ source: URL, to destination: URL) throws {
        let reader = try ImportReader(source)
        var writer: WAVFileWriter
        do {
            writer = try WAVFileWriter(creatingAt: destination)
        } catch {
            throw Failure.cannotWrite
        }
        var wroteBytes = 0
        while let pcm = try reader.nextChunk() {
            try writer.append(pcm: pcm)
            wroteBytes += pcm.count
        }
        try writer.finish()
        guard wroteBytes > 0 else {
            throw Failure.empty
        }
    }
}

/// 一塊一塊讀原檔、轉成 16 kHz 單聲道 16-bit，不整個讀進記憶體（一小時的 Podcast 也一樣）。
private final class ImportReader {
    private let input: AVAudioFile
    private let target: AVAudioFormat
    private let converter: AVAudioConverter
    private let inBuffer: AVAudioPCMBuffer
    private var isFinished = false

    init(_ source: URL) throws {
        guard let input = try? AVAudioFile(forReading: source),
              let target = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: Double(WAVFileWriter.sampleRate),
                  channels: AVAudioChannelCount(WAVFileWriter.channelCount),
                  interleaved: true
              ),
              let converter = AVAudioConverter(from: input.processingFormat, to: target),
              let inBuffer = AVAudioPCMBuffer(
                  pcmFormat: input.processingFormat,
                  frameCapacity: AudioImport.framesPerRead
              )
        else {
            throw AudioImport.Failure.cannotRead
        }
        self.input = input
        self.target = target
        self.converter = converter
        self.inBuffer = inBuffer
    }

    /// 讀完回 nil。
    func nextChunk() throws -> Data? {
        guard !isFinished else {
            return nil
        }
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: target,
            frameCapacity: AudioImport.framesPerRead
        ) else {
            throw AudioImport.Failure.cannotWrite
        }
        let status = converter.convert(to: outBuffer, error: nil) { [self] _, inputStatus in
            // 讀到底（或讀不下去）就告訴轉換器沒了，它會把手上剩的吐完。
            guard (try? input.read(into: inBuffer)) != nil, inBuffer.frameLength > 0 else {
                inputStatus.pointee = .endOfStream
                return nil
            }
            inputStatus.pointee = .haveData
            return inBuffer
        }
        isFinished = status == .endOfStream || status == .error || outBuffer.frameLength == 0
        guard let samples = outBuffer.int16ChannelData, outBuffer.frameLength > 0 else {
            return isFinished ? nil : Data()
        }
        let bytesPerFrame = WAVFileWriter.bitsPerSample / 8
        return Data(bytes: samples[0], count: Int(outBuffer.frameLength) * bytesPerFrame)
    }
}
