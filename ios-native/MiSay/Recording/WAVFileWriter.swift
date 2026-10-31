import Foundation

/// 方塊 M1：邊錄邊把 16-bit PCM 寫進 WAV 檔，不整捲抱在記憶體（舊版的死法，PRD 第 3 節）。
/// 自己寫而不用系統的 AVAudioFile，是因為 C4 要在 App 被殺掉後靠檔案大小修檔頭救回；自己寫的檔頭才修得準。
/// 檔頭 44 bytes 先寫佔位長度，`finish()` 才補真正的長度；中途被殺掉的檔，長度欄會是 0。
struct WAVFileWriter {
    enum Failure: Error, Equatable {
        case cannotCreate
        case cannotOpen
        case writeFailed
    }

    /// 44 bytes 標準 PCM WAV 檔頭；資料長度欄位在 4 與 40 兩處。
    static let headerByteCount = 44
    /// OpenAI 收得了、舊版就用的格式（PRD：16 kHz 單聲道）。
    static let sampleRate = 16000
    static let channelCount = 1
    static let bitsPerSample = 16

    let url: URL
    private let handle: FileHandle
    private var dataByteCount: UInt32 = 0

    /// 建新檔、寫入佔位檔頭。同名檔會被蓋掉：呼叫端用時間戳命名，不會撞。
    init(creatingAt url: URL) throws {
        self.url = url
        let placeholderHeader = Self.header(dataByteCount: 0)
        guard FileManager.default.createFile(atPath: url.path, contents: placeholderHeader) else {
            throw Failure.cannotCreate
        }
        do {
            handle = try FileHandle(forWritingTo: url)
            _ = try handle.seekToEnd()
        } catch {
            throw Failure.cannotOpen
        }
    }

    /// 寫一段 16-bit 小端 PCM。每次呼叫就落地一次，App 被殺掉最多丟最後一段。
    mutating func append(pcm: Data) throws {
        do {
            try handle.write(contentsOf: pcm)
        } catch {
            throw Failure.writeFailed
        }
        dataByteCount += UInt32(pcm.count)
    }

    /// 補真正的長度進檔頭並關檔。之後這個 writer 不能再用。
    func finish() throws {
        do {
            try handle.seek(toOffset: 0)
            try handle.write(contentsOf: Self.header(dataByteCount: dataByteCount))
            try handle.close()
        } catch {
            throw Failure.writeFailed
        }
    }

    /// 寫到目前為止的秒數，從位元組數換算，不靠計時器，鎖屏或卡頓也不會飄。
    var elapsedSeconds: Double {
        let bytesPerSecond = Self.sampleRate * Self.channelCount * Self.bitsPerSample / 8
        return Double(dataByteCount) / Double(bytesPerSecond)
    }

    static func header(dataByteCount: UInt32) -> Data {
        let bytesPerFrame = UInt16(channelCount * bitsPerSample / 8)
        let bytesPerSecond = UInt32(sampleRate) * UInt32(bytesPerFrame)
        var data = Data(capacity: headerByteCount)
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(36 + dataByteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1)) // PCM
        data.appendLittleEndian(UInt16(channelCount))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(bytesPerSecond)
        data.appendLittleEndian(bytesPerFrame)
        data.appendLittleEndian(UInt16(bitsPerSample))
        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(dataByteCount)
        return data
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt32) {
        var little = value.littleEndian
        append(Data(bytes: &little, count: 4))
    }

    mutating func appendLittleEndian(_ value: UInt16) {
        var little = value.littleEndian
        append(Data(bytes: &little, count: 2))
    }
}
