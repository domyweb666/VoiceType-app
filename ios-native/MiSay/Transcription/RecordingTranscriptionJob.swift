import Foundation

/// 方塊 M3：一個錄音（可能很長）→ 整篇口語稿。照 `WAVSegmenter` 切成約 5 分鐘一段、逐段送、每段成功就記進進度檔；
/// 失敗後再來只送還沒成功的段（PRD「斷網後從失敗段續轉」）。
/// 同一個錄音不會同時跑兩次是 D5 的事（它管在飛的清單）。
struct RecordingTranscriptionJob {
    enum Failure: Error, Equatable {
        case cannotSaveProgress
        /// 進度檔在，但一時讀不到（開機後還沒解鎖過）。
        case cannotReadProgress
    }

    static let progressExtension = "progress.json"

    let transcriber: Transcriber
    let vocabulary: [String]
    private let keyStore: TranscriptEncryptionKeyStore
    private let fileManager = FileManager.default

    init(
        transcriber: Transcriber = Transcriber(),
        vocabulary: [String] = [],
        keyStore: TranscriptEncryptionKeyStore = TranscriptEncryptionKeyStore()
    ) {
        self.transcriber = transcriber
        self.vocabulary = vocabulary
        self.keyStore = keyStore
    }

    /// 回整篇口語稿（各段直接接起來，舊版也是）。中途哪一段失敗就拋出那一段的錯，已成功的段留在進度檔。
    /// `onSegment` 在每段開始送之前叫（第幾段／共幾段），給面板畫「第 2／3 段」。
    func transcribe(
        recordingAt recordingURL: URL,
        onSegment: @MainActor (Int, Int) -> Void = { _, _ in }
    ) async throws -> String {
        let segments = try WAVSegmenter.plan(recordingURL)
        // 一個樣本都沒有：不存一篇空白口語稿、不送空的潤飾，當成讀不到。
        guard !segments.isEmpty else {
            throw WAVSegmenter.Failure.cannotRead
        }
        var progress = try loadProgress(for: recordingURL)
        progress.adopt(segments)
        let baseName = recordingURL.deletingPathExtension().lastPathComponent
        for (index, segment) in segments.enumerated() where progress.segmentTexts[index] == nil {
            // 回呼會改畫面讀的進度，要回主執行緒叫；這個函式本身跑在背景。
            await onSegment(index + 1, segments.count)
            let previousText = (0 ..< index).compactMap { progress.segmentTexts[$0] }.joined()
            let request = try SegmentRequest(
                audio: WAVSegmenter.read(segment, from: recordingURL),
                filename: String(format: "%@-%02d.wav", baseName, index + 1),
                prompt: TranscriptionPrompt.build(previousText: previousText),
                label: "轉錄第 \(index + 1)/\(segments.count) 段"
            )
            var text = try await send(request)
            // S2-2：字數少得不像那段講的話量，重送一次；還是少就記下來，文字稿標「可能漏字」。
            if Self.looksShort(text, audio: request.audio) {
                text = try await send(request)
                if Self.looksShort(text, audio: request.audio) {
                    progress.suspectSegments.insert(index)
                }
            }
            progress.segmentTexts[index] = text
            try saveProgress(progress, for: recordingURL)
        }
        return (0 ..< segments.count).compactMap { progress.segmentTexts[$0] }.joined()
    }

    /// 口語稿存進歷史前讀：錄音中先潤飾好、而且口語稿對得上的那幾塊（S4-1）。沒有就是 nil。
    func polishedChunks(
        matching rawText: String,
        polishedWith settings: String,
        forRecordingAt recordingURL: URL
    ) throws -> [String]? {
        let progress = try loadProgress(for: recordingURL)
        guard progress.polishedWith == settings else {
            return nil
        }
        let count = progress.polishedPrefixCount(matching: PolishChunks.split(rawText))
        return count == 0 ? nil : Array(progress.polishedDrafts.prefix(count))
    }

    /// 口語稿存進歷史前讀：每段在錄音裡的起訖秒數與字數（2026-11-15，聽原音跟讀用）。
    func timeline(forRecordingAt recordingURL: URL) throws -> [TimelineSpan]? {
        let progress = try loadProgress(for: recordingURL)
        return SpokenTimeline.spans(segments: progress.segments ?? [], texts: progress.segmentTexts)
    }

    /// 口語稿存進歷史前讀：可能漏字的段，從 1 數。沒有就是 nil（存進文字稿時不多一欄）。
    func possiblyMissingSegments(forRecordingAt recordingURL: URL) throws -> [Int]? {
        let suspects = try loadProgress(for: recordingURL).suspectSegments
        return suspects.isEmpty ? nil : suspects.sorted().map { $0 + 1 }
    }

    static let minSpeechSecondsToCheck: Double = 5
    static let minCharactersPerSpeechSecond: Double = 1

    /// 講話秒數夠長（短的一兩句不準）而且每秒不到一個字：正常中文每秒四、五個字，少到這樣多半是漏了。
    static func looksShort(_ text: String, audio: Data) -> Bool {
        let speech = WAVSegmenter.speechSeconds(in: audio)
        guard speech >= minSpeechSecondsToCheck else {
            return false
        }
        return Double(text.count) < speech * minCharactersPerSpeechSecond
    }

    struct SegmentRequest {
        let audio: Data
        let filename: String
        let prompt: String
        let label: String
    }

    func send(_ request: SegmentRequest) async throws -> String {
        let startedAt = Date()
        let text: String
        do {
            // S4-2：壓成 m4a 再送；壓不了照送 WAV。漏字判斷照舊看原本的 WAV。
            let compressed = AudioCompressor.m4a(fromWAV: request.audio)
            let filename = compressed == nil
                ? request.filename
                : (request.filename as NSString).deletingPathExtension + ".m4a"
            text = try await transcriber.transcribe(
                audio: compressed ?? request.audio,
                filename: filename,
                prompt: request.prompt,
                keywords: TranscriptionKeywords.usable(from: vocabulary)
            )
        } catch {
            let waited = Int(Date().timeIntervalSince(startedAt))
            DiagnosticLog.shared.record("\(request.label)失敗，等了 \(waited) 秒：\(error)")
            throw error
        }
        let waited = Int(Date().timeIntervalSince(startedAt))
        DiagnosticLog.shared.record("\(request.label)，等了 \(waited) 秒，\(text.count) 字")
        return text
    }

    /// 口語稿存進歷史之後（D5）才呼叫：把進度檔清掉。錄音檔本身由 D5 刪。
    /// 切段資料夾是 v0.2.1 以前另存的切段檔，新版不再產生，留著這行把舊的清掉。
    func cleanUp(recordingAt recordingURL: URL) {
        try? fileManager.removeItem(at: Self.segmentsDirectory(for: recordingURL))
        try? fileManager.removeItem(at: Self.progressURL(for: recordingURL))
    }

    /// 轉錄完之後呼叫；沒有進度檔、壞掉時給新的 id（最壞是多一篇，不會丟）。
    func transcriptID(forRecordingAt recordingURL: URL) throws -> UUID {
        try loadProgress(for: recordingURL).transcriptID
    }

    static func segmentsDirectory(for recordingURL: URL) -> URL {
        recordingURL.deletingPathExtension().appendingPathExtension("segments")
    }

    static func progressURL(for recordingURL: URL) -> URL {
        recordingURL.deletingPathExtension().appendingPathExtension(progressExtension)
    }

    /// 進度檔裡是一段一段的口語稿，跟文字稿一樣存 JSON（米 2026-11-25）。
    /// 舊版加密的用文字稿那把舊金鑰解，下次存就變 JSON。
    /// 沒有、壞了就當從頭開始：最多多送已成功的段。一時讀不到要丟錯，當成空的存回去會蓋掉轉好的段。
    func loadProgress(for recordingURL: URL) throws -> Progress {
        let url = Self.progressURL(for: recordingURL)
        guard fileManager.fileExists(atPath: url.path) else {
            return Progress()
        }
        let json: Data
        do {
            let data = try Data(contentsOf: url)
            json = try keyStore.unseal(data) ?? data
        } catch {
            throw Failure.cannotReadProgress
        }
        return (try? JSONDecoder().decode(Progress.self, from: json)) ?? Progress()
    }

    func saveProgress(_ progress: Progress, for recordingURL: URL) throws {
        do {
            let json = try JSONEncoder().encode(progress)
            try json.write(to: Self.progressURL(for: recordingURL), options: Self.writeOptions)
        } catch {
            throw Failure.cannotSaveProgress
        }
    }

    private static let writeOptions: Data.WritingOptions = [
        .atomic,
        .completeFileProtectionUntilFirstUserAuthentication,
    ]
}
