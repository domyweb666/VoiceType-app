import Foundation
import Observation
import UIKit

/// 方塊 M2 的流水（片 D5）：停止 → 收檔 → 判斷有金鑰 → 轉錄 → 口語稿存進歷史後才刪錄音檔 → 潤飾 → 草稿存進同一篇。
/// 條件齊了從最舊的開始自動續轉；某一筆失敗就停、不重跑（安全標準四）。同一段不會同時送兩次（inFlight）。
/// 畫面只讀 `activity`；要觸發用 `process` 或 `processPending`。
/// 拆成三個檔（S2-0）：本檔是一筆的轉錄與存口語稿，`+Polishing` 是潤飾，`+Pending` 是自動續轉。
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
        /// 口語稿存不進歷史：錄音檔還在待轉錄（沒動）。
        case storageFailed
        /// 潤飾回來了但存不進去：口語稿那一版還在歷史裡，錄音檔已刪。
        case draftNotSaved(Transcript)
        /// 錄音檔讀不到或切不了段（不是 OpenAI 的事）：檔還在待轉錄，沒送出去的不扣款。
        case recordingUnreadable
        /// 口語稿存好了但錄音檔搬不進留存區（S2-5 起不刪、改搬）：下一輪會從進度檔接回同一篇再存一次、
        /// 再潤飾一次（潤飾會再扣款）。名字沿用舊的，畫面已經接這個結局。
        case recordingNotDeleted(Transcript)
    }

    /// `Result` 的失敗那一邊要是 Error；包一層讓轉錄、存口語稿這兩步能把要停下來的結局帶回來。
    /// `value` 是 nil 表示被取消：不給結局，呼叫端當沒發生。
    struct StoppedOutcome: Error {
        let value: Outcome?
    }

    /// 畫面只讀；會改它的只有這個型別自己的幾個檔（本檔與 `TranscriptionQueue+` 開頭的）。
    /// S2-7：整理中螢幕不自動暗，按鎖屏時跟系統要最後約 30 秒把手上這段做完。
    var activity = Activity.idle {
        didSet { keepWorkingIfBusy() }
    }

    /// OpenAI 拒收（4xx）或讀不出來的錄音檔名：再送一次也一樣，自動續轉跳過它們，待轉錄清單標出來給使用者刪。
    /// 只記在記憶體：重開米說會再試一次（2026-11-02 米：照建議，不讓一筆擋住後面的）。
    var refusedRecordings: Set<String> = []
    /// 在飛的錄音檔名與正在潤飾的篇 id（S2-4：補潤飾時不重送同一篇）。
    var inFlight: Set<String> = []
    var isProcessingPending = false
    /// 最近一次自動續轉（S2-7）：回到前景時要取消重來的就是它。
    var pendingRun: Task<Void, Never>?
    /// 邊錄邊轉那一輪（S4-1）；沒在錄是 nil。
    var liveRun: Task<Void, Never>?
    var lastBackgroundedAt: Date?
    private let workingHold = BackgroundTimeHold()

    let pending = PendingRecordings()
    let retained = RetainedRecordings()
    private let keyStore = APIKeyStore()
    let store = TranscriptStore()
    let transcriber: Transcriber
    let polisher: Polisher
    let settings: AppSettings

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
        switch saveRawThenRetainRecording(rawText, recordingAt: url, job: job) {
        case let .success(saved):
            transcript = saved
        case let .failure(outcome):
            return outcome.value
        }
        activity = .polishing(recording: name)
        let polishKey = transcript.id.uuidString
        inFlight.insert(polishKey)
        defer { inFlight.remove(polishKey) }
        return await polishAndSave(transcript)
    }

    /// 轉錄這一步。OpenAI 的錯原樣帶回；讀不到錄音是 `.recordingUnreadable`；被取消時不給結局。
    /// S2-6：其他錯（金鑰一時讀不到、進度檔寫不進去）不是錄音壞了，當成「等一下再試」，不標紅字叫人刪。
    func transcribe(
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
        } catch is WAVSegmenter.Failure, Transcriber.Failure.cannotReadFile {
            return .failure(StoppedOutcome(value: .recordingUnreadable))
        } catch {
            DiagnosticLog.shared.record("轉錄停下，等一下再試：\(type(of: error))")
            return .failure(StoppedOutcome(value: .transcriptionFailed(.malformedResponse)))
        }
    }

    /// 口語稿落地之後才准把錄音搬離待轉錄（安全標準二）；搬好之後才清進度檔，
    /// 不然錄音搬不走時進度也沒了，下一輪只能整段重送。S2-5 起錄音不刪，搬進留存區等文字稿存好再留 7 天。
    private func saveRawThenRetainRecording(
        _ rawText: String,
        recordingAt url: URL,
        job: RecordingTranscriptionJob
    ) -> Result<Transcript, StoppedOutcome> {
        let name = url.lastPathComponent
        let duration = (try? pending.list().first { $0.id == name }?.durationSeconds) ?? 0
        let transcript = Transcript(
            id: job.transcriptID(forRecordingAt: url),
            durationSeconds: duration,
            rawText: rawText,
            possiblyMissingSegments: job.possiblyMissingSegments(forRecordingAt: url),
            polishedChunks: job.polishedChunks(matching: rawText, forRecordingAt: url)
        )
        do {
            try store.save(transcript)
        } catch {
            return .failure(StoppedOutcome(value: .storageFailed))
        }
        do {
            try retained.retain(recordingAt: url, for: transcript.id)
        } catch {
            return .failure(StoppedOutcome(value: .recordingNotDeleted(transcript)))
        }
        job.cleanUp(recordingAt: url)
        return .success(transcript)
    }

    private func keepWorkingIfBusy() {
        let isBusy = activity != .idle
        UIApplication.shared.isIdleTimerDisabled = isBusy
        if isBusy {
            workingHold.begin()
        } else {
            workingHold.end()
        }
    }

    /// 只有正在顯示的是這一筆時才歸零：面板與續轉可能同時各跑一筆，不能蓋掉另一筆的進度。
    func resetActivity(ifShowing recording: String) {
        switch activity {
        case let .transcribing(name, _, _), let .polishing(name):
            if name == recording {
                activity = .idle
            }
        case .idle:
            break
        }
    }
}
