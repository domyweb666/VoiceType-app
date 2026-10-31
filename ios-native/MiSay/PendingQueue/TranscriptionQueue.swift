import Foundation
import Observation

/// 方塊 M2 的流水（片 D5）：停止 → 收檔 → 判斷有金鑰 → 轉錄 → 口語稿存進歷史後才刪錄音檔 → 潤飾 → 草稿存進同一篇。
/// 條件齊了從最舊的開始自動續轉；某一筆失敗就停、不重跑（安全標準四）。同一段不會同時送兩次（inFlight）。
/// 畫面只讀 `activity`；要觸發用 `process` 或 `processPending`。
@Observable
@MainActor
final class TranscriptionQueue {
    /// 一筆錄音整理到哪：給錄音面板（D6）畫「整理中…第 2／3 段」。
    enum Activity: Equatable {
        case idle
        case transcribing(recording: String, segment: Int, totalSegments: Int)
        case polishing(recording: String)
    }

    /// 一筆錄音整理完的結局。口語稿一存進歷史，錄音檔就刪了（PRD）；潤飾失敗時口語稿還在歷史裡。
    enum Outcome: Equatable {
        case noAPIKey
        case transcriptionFailed(OpenAIClient.Failure)
        case polishFailed(Transcript, OpenAIClient.Failure)
        case finished(Transcript)
        case storageFailed
    }

    private(set) var activity = Activity.idle
    private var inFlight: Set<String> = []

    private let pending = PendingRecordings()
    private let keyStore = APIKeyStore()
    private let store = TranscriptStore()
    private let transcriber: Transcriber
    private let polisher: Polisher
    private let vocabulary: [String]
    private let polishModel: String
    private let polishPrompt: String

    /// 模型、提示詞、詞彙先用 M4／M3 的預設；組塊 F 的設定接上後從 M7 讀。
    init(
        transcriber: Transcriber = Transcriber(),
        polisher: Polisher = Polisher(),
        vocabulary: [String] = [],
        polishModel: String = Polisher.defaultModel,
        polishPrompt: String = Polisher.defaultPrompt
    ) {
        self.transcriber = transcriber
        self.polisher = polisher
        self.vocabulary = vocabulary
        self.polishModel = polishModel
        self.polishPrompt = polishPrompt
    }

    /// 整理一筆。已經在飛的那一筆直接回 nil（不重送）。
    func process(recordingAt url: URL) async -> Outcome? {
        let name = url.lastPathComponent
        guard !inFlight.contains(name) else {
            return nil
        }
        inFlight.insert(name)
        defer {
            inFlight.remove(name)
            activity = .idle
        }

        guard (try? keyStore.read()) != nil else {
            return .noAPIKey
        }

        let job = RecordingTranscriptionJob(transcriber: transcriber, vocabulary: vocabulary)
        let rawText: String
        do {
            rawText = try await job.transcribe(recordingAt: url) { [weak self] segment, total in
                self?.activity = .transcribing(
                    recording: name,
                    segment: segment,
                    totalSegments: total
                )
            }
        } catch let failure as OpenAIClient.Failure {
            return .transcriptionFailed(failure)
        } catch {
            return .transcriptionFailed(.malformedResponse)
        }

        let duration = (try? pending.list().first { $0.id == name }?.durationSeconds) ?? 0
        var transcript = Transcript(durationSeconds: duration, rawText: rawText)
        do {
            try store.save(transcript)
        } catch {
            return .storageFailed
        }
        // 口語稿已經落地，這時才准刪錄音檔與切段（安全標準二：存好才准刪）。
        job.cleanUp(recordingAt: url)
        let recordingFile = PendingRecordings.Recording(url: url, recordedAt: .distantPast, durationSeconds: 0)
        try? pending.delete(recordingFile)

        activity = .polishing(recording: name)
        do {
            let draft = try await polisher.polish(
                rawText: rawText,
                model: polishModel,
                systemPrompt: polishPrompt,
                vocabulary: vocabulary
            )
            transcript.draftText = draft
            transcript.polishModel = polishModel
            transcript.updatedAt = Date()
        } catch let failure as OpenAIClient.Failure {
            return .polishFailed(transcript, failure)
        } catch {
            return .polishFailed(transcript, .malformedResponse)
        }
        do {
            try store.save(transcript)
        } catch {
            return .storageFailed
        }
        return .finished(transcript)
    }

    /// 自動續轉：從最舊的開始，一筆一筆；哪一筆失敗就停，等下次條件齊了再來。
    func processPending() async {
        guard let recordings = try? pending.list() else {
            return
        }
        for recording in recordings.reversed() {
            let outcome = await process(recordingAt: recording.url)
            switch outcome {
            case .finished, .polishFailed, nil:
                continue
            case .noAPIKey, .transcriptionFailed, .storageFailed:
                return
            }
        }
    }
}
