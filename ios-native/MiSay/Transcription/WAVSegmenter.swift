import Foundation

/// 方塊 M3：超過 10 分鐘的 WAV 切成一段一段（PRD：10 分鐘切段；OpenAI 單檔 25 MB 上限，
/// 10 分鐘的 16 kHz 單聲道是 19.2 MB）。每段都是完整的 WAV，各自有檔頭。
/// 切的時候用 FileHandle 一段一段讀，不整檔讀進記憶體。
enum WAVSegmenter {
    enum Failure: Error, Equatable {
        case cannotRead
        case cannotWrite
    }

    static let maxSegmentSeconds = 600

    /// 不超過一段長度就原檔送回（不複製）；超過就切進 `directory`，檔名「原檔名-01.wav」起跳。
    static func split(_ source: URL, into directory: URL) throws -> [URL] {
        let bytesPerFrame = WAVFileWriter.channelCount * WAVFileWriter.bitsPerSample / 8
        let bytesPerSecond = WAVFileWriter.sampleRate * bytesPerFrame
        let segmentByteCount = bytesPerSecond * maxSegmentSeconds
        let header = WAVFileWriter.headerByteCount
        let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        let dataByteCount = max(0, fileSize - header)
        guard dataByteCount > segmentByteCount else {
            return [source]
        }

        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: source)
        } catch {
            throw Failure.cannotRead
        }
        defer { try? handle.close() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let baseName = source.deletingPathExtension().lastPathComponent
        var segments: [URL] = []
        var offset = 0
        while offset < dataByteCount {
            let length = min(segmentByteCount, dataByteCount - offset)
            let chunk: Data?
            do {
                try handle.seek(toOffset: UInt64(header + offset))
                chunk = try handle.read(upToCount: length)
            } catch {
                throw Failure.cannotRead
            }
            guard let chunk, chunk.count == length else {
                throw Failure.cannotRead
            }
            let segmentName = String(format: "%@-%02d.wav", baseName, segments.count + 1)
            try segments.append(writeSegment(chunk, to: directory.appending(path: segmentName)))
            offset += length
        }
        return segments
    }

    /// 每段都補上自己的檔頭，OpenAI 才當它是完整的 WAV。
    private static func writeSegment(_ pcm: Data, to url: URL) throws -> URL {
        var segment = WAVFileWriter.header(dataByteCount: UInt32(pcm.count))
        segment.append(pcm)
        do {
            try segment.write(to: url, options: .atomic)
        } catch {
            throw Failure.cannotWrite
        }
        return url
    }
}
