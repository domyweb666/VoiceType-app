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
        /// 錄音檔讀不到或切不了段（不是 OpenAI 的事）：檔還在待轉錄，沒送出去的不扣款。
        case recordingUnreadable
        /// 口語稿存好了但錄音檔刪不掉：下一輪會從進度檔接回同一篇再存一次、再潤飾一次（潤飾會再扣款）。
        case recordingNotDeleted(Transcript)
    }

    /// `Result` 的失敗那一邊要是 Error；包一層讓轉錄、存口語稿這兩步能把要停下來的結局帶回來。
    /// `value` 是 nil 表示被取消：不給結局，呼叫端當沒發生。
    private struct StoppedOutcome: Error {
        let value: Outcome?
    }

    private(set) var activity = Activity.idle
    /// OpenAI 拒收（4xx）或讀不出來的錄音檔名：再送一次也一樣，自動續轉跳過它們，待轉錄清單標出來給使用者刪。
    /// 只記在記憶體：重開米說會再試一次（2026-11-02 米：照建議，不讓一筆擋住後面的）。
    private(set) var refusedRecordings: Set<String> = []
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
            resetActivity(ifShowing: name)
        }

        guard (try? keyStore.read()) != nil else {
            return .noAPIKey
        }

        let job = RecordingTranscriptionJob(
            transcriber: transcriber,
            vocabulary: settings.vocabulary
        )
        let rawText: String
        switch await transcribe(url, with: job) {
        case let .success(text):
            rawText = text
        case let .failure(stopped):
            return stopped.value
        }

        let transcript: Transcript
        switch saveRawThenDeleteRecording(rawText, recordingAt: url, job: job) {
        case let .success(saved):
            transcript = saved
        case let .failure(outcome):
            return outcome.value
        }
        activity = .polishing(recording: name)
        return await polishAndSave(transcript)
    }

    /// 轉錄這一步。OpenAI 的錯原樣帶回；讀不到錄音、切不了段是 `.recordingUnreadable`；被取消時不給結局。
    private func transcribe(
        _ url: URL,
        with job: RecordingTranscriptionJob
    ) async -> Result<String, StoppedOutcome> {
        let name = url.lastPathComponent
        do {
            let text = try await job.transcribe(recordingAt: url) { [weak self] segment, total in
                self?.activity = .transcribing(
                    recording: name,
                    segment: segment,
                    totalSegments: total
                )
            }
            return .success(text)
        } catch let failure as OpenAIClient.Failure {
            return .failure(StoppedOutcome(value: .transcriptionFailed(failure)))
        } catch is CancellationError {
            return .failure(StoppedOutcome(value: nil))
        } catch {
            return .failure(StoppedOutcome(value: .recordingUnreadable))
        }
    }

    /// 口語稿落地之後才准刪錄音檔（安全標準二：存好才准刪）；錄音檔刪掉之後才清切段與進度檔，
    /// 不然錄音刪不掉時進度也沒了，下一輪只能整段重送。
    private func saveRawThenDeleteRecording(
        _ rawText: String,
        recordingAt url: URL,
        job: RecordingTranscriptionJob
    ) -> Result<Transcript, StoppedOutcome> {
        let name = url.lastPathComponent
        let duration = (try? pending.list().first { $0.id == name }?.durationSeconds) ?? 0
        let transcript = Transcript(
            id: job.transcriptID(forRecordingAt: url),
            durationSeconds: duration,
            rawText: rawText
        )
        do {
            try store.save(transcript)
        } catch {
            return .failure(StoppedOutcome(value: .storageFailed))
        }
        do {
            try pending.delete(recordingAt: url)
        } catch {
            return .failure(StoppedOutcome(value: .recordingNotDeleted(transcript)))
        }
        job.cleanUp(recordingAt: url)
        return .success(transcript)
    }

    /// 只有正在顯示的是這一筆時才歸零：面板與續轉可能同時各跑一筆，不能蓋掉另一筆的進度。
    private func resetActivity(ifShowing recording: String) {
        switch activity {
        case let .transcribing(name, _, _), let .polishing(name):
            if name == recording {
                activity = .idle
            }
        case .idle:
            break
        }
    }

    /// 片 D6「重試潤飾」：口語稿已在歷史，只重送潤飾，成功就存回同一篇。
    func retryPolish(_ transcript: Transcript) async -> Outcome {
        let name = transcript.id.uuidString
        activity = .polishing(recording: name)
        defer { resetActivity(ifShowing: name) }
        return await polishAndSave(transcript)
    }

    private func polishAndSave(_ transcript: Transcript) async -> Outcome {
        var polished = transcript
        let model = settings.polishModel
        let startedAt = Date()
        do {
            let draft = try await polisher.polish(
                rawText: transcript.rawText,
                model: model,
                systemPrompt: settings.effectivePolishPrompt,
                vocabulary: settings.vocabulary
            )
            polished.draftText = draft
            polished.polishModel = model
            polished.updatedAt = Date()
            let waited = Int(Date().timeIntervalSince(startedAt))
            DiagnosticLog.shared.record(
                "潤飾 \(model)，等了 \(waited) 秒，\(transcript.rawText.count) 字變 \(draft.count) 字"
            )
        } catch let failure as OpenAIClient.Failure {
            logPolishFailure(failure, model: model, startedAt: startedAt)
            return .polishFailed(transcript, failure)
        } catch {
            logPolishFailure(error, model: model, startedAt: startedAt)
            return .polishFailed(transcript, .malformedResponse)
        }
        do {
            try store.save(polished)
        } catch {
            return .draftNotSaved(transcript)
        }
        return .finished(polished)
    }

    private func logPolishFailure(_ error: Error, model: String, startedAt: Date) {
        let waited = Int(Date().timeIntervalSince(startedAt))
        DiagnosticLog.shared.record("潤飾 \(model) 失敗，等了 \(waited) 秒：\(error)")
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
            let exists = FileManager.default.fileExists(atPath: recording.url.path)
            guard exists, !refusedRecordings.contains(recording.id) else {
                continue
            }
            let outcome = await process(recordingAt: recording.url)
            switch outcome {
            case .finished, .polishFailed, .draftNotSaved, nil:
                continue
            case .transcriptionFailed(.rejected), .recordingUnreadable:
                refusedRecordings.insert(recording.id)
            case .noAPIKey, .transcriptionFailed, .storageFailed, .recordingNotDeleted:
                return
            }
        }
    }
}
