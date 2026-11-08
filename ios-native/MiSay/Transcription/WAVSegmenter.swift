import Foundation

/// 方塊 M3：長錄音怎麼切段（S2-1，2026-11-08 起）。每段約 5 分鐘，刀下在 4:30～5:30 之間最安靜的地方，
/// 不切在句子中間；不滿 30 秒的尾巴併進前一段。只算起訖位置，不另存切段檔：送的時候直接從原檔讀那一段，
/// 一小時省 115 MB。5 分鐘中文約 1,200～1,700 token，碰不到轉錄的長度上限；檔案約 9.6 MB，離 25 MB 很遠。
enum WAVSegmenter {
    enum Failure: Error, Equatable {
        case cannotRead
    }

    /// 一段的起訖，單位是 frame（16 kHz 單聲道，一個 frame 一個樣本）。存進進度檔，對不上就從頭轉。
    struct Segment: Codable, Equatable {
        let startFrame: Int
        let endFrame: Int
    }

    static let targetSegmentSeconds = 300
    static let earliestCutSeconds = 270
    static let latestCutSeconds = 330
    static let minTailSeconds = 30
    /// 量安靜的單位：0.1 秒一格，比一個字短，夠找到換氣的空檔。
    static let quietWindowFrames = WAVFileWriter.sampleRate / 10
    /// 一格的平均振幅超過這個算「有在講話」（約 -36 dBFS）。只拿來估字數夠不夠，不拿來切。
    static let speechLoudnessThreshold = 500

    private static var bytesPerFrame: Int {
        WAVFileWriter.channelCount * WAVFileWriter.bitsPerSample / 8
    }

    /// 讀檔頭後的長度，量每個候選區間最安靜的位置，切出整份錄音的段。
    static func plan(_ source: URL) throws -> [Segment] {
        let totalFrames = try dataByteCount(of: source) / bytesPerFrame
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: source)
        } catch {
            throw Failure.cannotRead
        }
        defer { try? handle.close() }
        return try plan(totalFrames: totalFrames) { range in
            try quietestFrame(in: range, handle: handle)
        }
    }

    /// 錄音中（S4-1）：已經錄到的部分裡，刀位不會再變的那幾段。最後一段還在長，不算。
    /// 每一刀只看那一分鐘的聲音，那一分鐘錄完了刀位就定了，停止後整份重切也會切在同一個地方
    /// （只有最後不滿 30 秒的尾巴會併進前一段，那一段停止後重轉）。
    static func finishedSegments(ofLive source: URL) throws -> [Segment] {
        try Array(plan(source).dropLast())
    }

    /// 純切法（CI 測得到）：`quietestFrame` 回「這個區間裡最安靜的那一格從哪個 frame 開始」。
    static func plan(
        totalFrames: Int,
        quietestFrame: (Range<Int>) throws -> Int
    ) rethrows -> [Segment] {
        let rate = WAVFileWriter.sampleRate
        var segments: [Segment] = []
        var start = 0
        while totalFrames - start > latestCutSeconds * rate {
            let search = (start + earliestCutSeconds * rate) ..< (start + latestCutSeconds * rate)
            let cut = try quietestFrame(search)
            segments.append(Segment(startFrame: start, endFrame: cut))
            start = cut
        }
        guard totalFrames > start else {
            return segments
        }
        if let last = segments.last, totalFrames - start < minTailSeconds * rate {
            segments[segments.count - 1] = Segment(
                startFrame: last.startFrame,
                endFrame: totalFrames
            )
        } else {
            segments.append(Segment(startFrame: start, endFrame: totalFrames))
        }
        return segments
    }

    /// 那一段補上自己的檔頭，OpenAI 才當它是完整的 WAV。一段約 9.6 MB，讀進記憶體送出就丟。
    static func read(_ segment: Segment, from source: URL) throws -> Data {
        let length = (segment.endFrame - segment.startFrame) * bytesPerFrame
        let pcm = try readPCM(
            from: source,
            byteOffset: segment.startFrame * bytesPerFrame,
            length: length
        )
        var audio = WAVFileWriter.header(dataByteCount: UInt32(pcm.count))
        audio.append(pcm)
        return audio
    }

    /// 一段完整 WAV（含檔頭）裡有幾秒在講話：給 S2-2 估「字數少得不對勁」。
    static func speechSeconds(in audio: Data) -> Double {
        let pcm = audio.dropFirst(WAVFileWriter.headerByteCount)
        var speechWindows = 0
        pcm.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            var windowStart = 0
            while windowStart + quietWindowFrames <= samples.count {
                var loudness = 0
                for sample in samples[windowStart ..< windowStart + quietWindowFrames] {
                    loudness += abs(Int(Int16(littleEndian: sample)))
                }
                if loudness / quietWindowFrames > speechLoudnessThreshold {
                    speechWindows += 1
                }
                windowStart += quietWindowFrames
            }
        }
        return Double(speechWindows * quietWindowFrames) / Double(WAVFileWriter.sampleRate)
    }

    private static func dataByteCount(of source: URL) throws -> Int {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: source.path)
        } catch {
            throw Failure.cannotRead
        }
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        return max(0, fileSize - WAVFileWriter.headerByteCount)
    }

    /// 一格一格加總振幅，最小的那格勝；一樣小時挑離 5 分鐘最近的（整段靜音時剛好切在 5:00）。
    private static func quietestFrame(in range: Range<Int>, handle: FileHandle) throws -> Int {
        let pcm = try readPCM(
            handle: handle,
            byteOffset: range.lowerBound * bytesPerFrame,
            length: range.count * bytesPerFrame
        )
        let target = range.lowerBound + (targetSegmentSeconds - earliestCutSeconds)
            * WAVFileWriter.sampleRate
        var best = (loudness: Int.max, distance: Int.max, frame: range.lowerBound)
        pcm.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            var windowStart = 0
            while windowStart + quietWindowFrames <= samples.count {
                var loudness = 0
                for sample in samples[windowStart ..< windowStart + quietWindowFrames] {
                    loudness += abs(Int(Int16(littleEndian: sample)))
                }
                let frame = range.lowerBound + windowStart
                let distance = abs(frame - target)
                let isQuieter = loudness < best.loudness
                let isCloserTie = loudness == best.loudness && distance < best.distance
                if isQuieter || isCloserTie {
                    best = (loudness, distance, frame)
                }
                windowStart += quietWindowFrames
            }
        }
        return best.frame
    }

    private static func readPCM(from source: URL, byteOffset: Int, length: Int) throws -> Data {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: source)
        } catch {
            throw Failure.cannotRead
        }
        defer { try? handle.close() }
        return try readPCM(handle: handle, byteOffset: byteOffset, length: length)
    }

    private static func readPCM(handle: FileHandle, byteOffset: Int, length: Int) throws -> Data {
        let chunk: Data?
        do {
            try handle.seek(toOffset: UInt64(WAVFileWriter.headerByteCount + byteOffset))
            chunk = try handle.read(upToCount: length)
        } catch {
            throw Failure.cannotRead
        }
        guard let chunk, chunk.count == length else {
            throw Failure.cannotRead
        }
        return chunk
    }
}
