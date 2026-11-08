import Foundation

/// 方塊 M3：一個錄音（可能很長）→ 整篇口語稿。照 `WAVSegmenter` 切成約 5 分鐘一段、逐段送、每段成功就記進進度檔；
/// 失敗後再來只送還沒成功的段（PRD「斷網後從失敗段續轉」）。
/// 同一個錄音不會同時跑兩次是 D5 的事（它管在飛的清單）。
struct RecordingTranscriptionJob {
    enum Failure: Error, Equatable {
        case cannotSaveProgress
    }

    /// 進度檔：哪幾段已經有口語稿，以及這段錄音存進歷史時用哪個 id。放在錄音檔旁邊，錄音刪掉時一起刪。
    /// id 先定好：口語稿存好但錄音刪不掉時，下一輪存回同一篇，不會多一篇重複的。
    /// 每段的起訖與切法版本一起記（S2-1）：舊版照 10 分鐘切的進度檔沒有這兩欄，對不上就從頭轉，
    /// 不拿舊段的字接新段；id 照舊沿用，不會多一篇。
    struct Progress: Codable, Equatable {
        static let currentPlanVersion = 2

        var segmentTexts: [Int: String] = [:]
        var transcriptID = UUID()
        var planVersion: Int?
        var segments: [WAVSegmenter.Segment]?
        /// 重送一次字數還是少的段（從 0 數，S2-2）。
        var suspectSegments: Set<Int> = []

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            segmentTexts = try container.decodeIfPresent(
                [Int: String].self,
                forKey: .segmentTexts
            ) ?? [:]
            transcriptID = try container.decode(UUID.self, forKey: .transcriptID)
            planVersion = try container.decodeIfPresent(Int.self, forKey: .planVersion)
            segments = try container.decodeIfPresent(
                [WAVSegmenter.Segment].self,
                forKey: .segments
            )
            suspectSegments = try container.decodeIfPresent(
                Set<Int>.self,
                forKey: .suspectSegments
            ) ?? []
        }

        /// 切法換了或段落對不上：已轉的字作廢，id 留著。
        mutating func adopt(_ plan: [WAVSegmenter.Segment]) {
            guard planVersion != Self.currentPlanVersion || segments != plan else {
                return
            }
            segmentTexts = [:]
            suspectSegments = []
            planVersion = Self.currentPlanVersion
            segments = plan
        }
    }

    static let progressExtension = "progress.json"

    private let transcriber: Transcriber
    private let vocabulary: [String]
    private let fileManager = FileManager.default

    init(transcriber: Transcriber = Transcriber(), vocabulary: [String] = []) {
        self.transcriber = transcriber
        self.vocabulary = vocabulary
    }

    /// 回整篇口語稿（各段直接接起來，舊版也是）。中途哪一段失敗就拋出那一段的錯，已成功的段留在進度檔。
    /// `onSegment` 在每段開始送之前叫（第幾段／共幾段），給面板畫「第 2／3 段」。
    func transcribe(
        recordingAt recordingURL: URL,
        onSegment: @MainActor (Int, Int) -> Void = { _, _ in }
    ) async throws -> String {
        let segments = try WAVSegmenter.plan(recordingURL)
        var progress = loadProgress(for: recordingURL)
        progress.adopt(segments)
        let baseName = recordingURL.deletingPathExtension().lastPathComponent
        for (index, segment) in segments.enumerated() where progress.segmentTexts[index] == nil {
            // 回呼會改畫面讀的進度，要回主執行緒叫；這個函式本身跑在背景。
            await onSegment(index + 1, segments.count)
            let previousText = (0 ..< index).compactMap { progress.segmentTexts[$0] }.joined()
            let request = try SegmentRequest(
                audio: WAVSegmenter.read(segment, from: recordingURL),
                filename: String(format: "%@-%02d.wav", baseName, index + 1),
                prompt: TranscriptionPrompt.build(
                    vocabulary: vocabulary,
                    previousText: previousText
                ),
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

    /// 口語稿存進歷史前讀：可能漏字的段，從 1 數。沒有就是 nil（存進文字稿時不多一欄）。
    func possiblyMissingSegments(forRecordingAt recordingURL: URL) -> [Int]? {
        let suspects = loadProgress(for: recordingURL).suspectSegments
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

    private struct SegmentRequest {
        let audio: Data
        let filename: String
        let prompt: String
        let label: String
    }

    private func send(_ request: SegmentRequest) async throws -> String {
        let startedAt = Date()
        let text: String
        do {
            text = try await transcriber.transcribe(
                audio: request.audio,
                filename: request.filename,
                prompt: request.prompt
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

    /// 轉錄完之後呼叫；進度檔讀不到時給新的 id（最壞是多一篇，不會丟）。
    func transcriptID(forRecordingAt recordingURL: URL) -> UUID {
        loadProgress(for: recordingURL).transcriptID
    }

    static func segmentsDirectory(for recordingURL: URL) -> URL {
        recordingURL.deletingPathExtension().appendingPathExtension("segments")
    }

    static func progressURL(for recordingURL: URL) -> URL {
        recordingURL.deletingPathExtension().appendingPathExtension(progressExtension)
    }

    private func loadProgress(for recordingURL: URL) -> Progress {
        // 進度檔讀不到就當從頭開始：最多多送已成功的段，不會丟任何東西。
        guard let data = try? Data(contentsOf: Self.progressURL(for: recordingURL)) else {
            return Progress()
        }
        return (try? JSONDecoder().decode(Progress.self, from: data)) ?? Progress()
    }

    private func saveProgress(_ progress: Progress, for recordingURL: URL) throws {
        do {
            let data = try JSONEncoder().encode(progress)
            try data.write(to: Self.progressURL(for: recordingURL), options: .atomic)
        } catch {
            throw Failure.cannotSaveProgress
        }
    }
}
