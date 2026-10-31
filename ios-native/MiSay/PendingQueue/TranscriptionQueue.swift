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
        /// 口語稿存不進歷史：錄音檔還在待轉錄（沒刪）。
        case storageFailed
        /// 潤飾回來了但存不進去：口語稿那一版還在歷史裡，錄音檔已刪。
        case draftNotSaved(Transcript)
    }

    private(set) var activity = Activity.idle
    private var inFlight: Set<String> = []
    private var isProcessingPending = false

    private let pending = PendingRecordings()
    private let keyStore = APIKeyStore()
    private let store = TranscriptStore()
    private let transcriber: Transcriber
    private let polisher: Polisher
    private let settings: AppSettings

    /// 模型、提示詞、詞彙每一筆開始時才從 M7 讀（片 F2～F4）：改了設定，下一筆就照新的走。
    init(
        transcriber: Transcriber = Transcriber(),
        polisher: Polisher = Polisher(),
        settings: AppSettings = .shared
    ) {
        self.transcriber = transcriber
        self.polisher = polisher
        self.settings = settings
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

        let job = RecordingTranscriptionJob(
            transcriber: transcriber,
            vocabulary: settings.vocabulary
        )
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
        let transcript = Transcript(durationSeconds: duration, rawText: rawText)
        do {
            try store.save(transcript)
        } catch {
            return .storageFailed
        }
        // 口語稿已經落地，這時才准刪錄音檔與切段（安全標準二：存好才准刪）。
        job.cleanUp(recordingAt: url)
        let recordingFile = PendingRecordings.Recording(
            url: url,
            recordedAt: .distantPast,
            durationSeconds: 0
        )
        try? pending.delete(recordingFile)

        activity = .polishing(recording: name)
        return await polishAndSave(transcript)
    }

    /// 片 D6「重試潤飾」：口語稿已在歷史，只重送潤飾，成功就存回同一篇。
    func retryPolish(_ transcript: Transcript) async -> Outcome {
        activity = .polishing(recording: transcript.id.uuidString)
        defer { activity = .idle }
        return await polishAndSave(transcript)
    }

    private func polishAndSave(_ transcript: Transcript) async -> Outcome {
        var polished = transcript
        let model = settings.polishModel
        do {
            polished.draftText = try await polisher.polish(
                rawText: transcript.rawText,
                model: model,
                systemPrompt: settings.effectivePolishPrompt,
                vocabulary: settings.vocabulary
            )
            polished.polishModel = model
            polished.updatedAt = Date()
        } catch let failure as OpenAIClient.Failure {
            return .polishFailed(transcript, failure)
        } catch {
            return .polishFailed(transcript, .malformedResponse)
        }
        do {
            try store.save(polished)
        } catch {
            return .draftNotSaved(transcript)
        }
        return .finished(polished)
    }

    /// 自動續轉：從最舊的開始，一筆一筆；哪一筆失敗就停，等下次條件齊了再來。
    func processPending() async {
        // 首頁出現、回到前景都會叫；同一時間只跑一輪，不然兩輪會交錯、「失敗就停」就不準了。
        guard !isProcessingPending, let recordings = try? pending.list() else {
            return
        }
        isProcessingPending = true
        defer { isProcessingPending = false }
        for recording in recordings.reversed() {
            // 清單是開跑時拍的照：這段時間面板可能已經整理完那一筆、錄音檔已刪。
            guard FileManager.default.fileExists(atPath: recording.url.path) else {
                continue
            }
            let outcome = await process(recordingAt: recording.url)
            switch outcome {
            case .finished, .polishFailed, .draftNotSaved, nil:
                continue
            case .noAPIKey, .transcriptionFailed, .storageFailed:
                return
            }
        }
    }
}
