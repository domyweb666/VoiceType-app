import SwiftUI

/// 錄音面板（半頁模態，不可下滑關閉：03-線框「錄到一半誤滑就丟掉」）。
/// 片 C1：錄音中、失敗、停止；片 C2：麥克風被拒；片 D6：停止後交給 `RecordingResultView`。
/// 組塊 S：錄音狀態在 App 層的 `Recorder`，這裡只讀；被打斷時換字，接回來就換回去。
/// 2026-11-07 統一風格：面板白底、計時 56、「正在聽」帶紅點、主要按鈕玉米黃膠囊、文字鈕金色；
/// 給人唸的字串搬到 `RecordingSheetView+Text.swift`。
/// 2026-11-26 米：首頁錄音不彈窗。首頁傳 `onClose` 進來就是原地版（`+Inline`），編輯頁「接著錄」照舊是半頁。
struct RecordingSheetView: View {
    enum Phase: Equatable {
        case starting
        case recording
        case interrupted
        case microphoneDenied
        case failed(String)
        /// 已收進待轉錄，這個位置的檔交給流水整理。
        case processing(URL)
    }

    let queue: TranscriptionQueue
    let recorder: Recorder
    let onOpenTranscript: (Transcript) -> Void
    let onOpenSettings: () -> Void
    /// K3 接著錄：錄好的這段整理完要接到哪一篇後面；一般開錄是 nil。
    var appendingTo: UUID?
    /// 接著錄要插在那篇的哪裡（打字時按麥克風記下的游標）；nil 是接在最後面。
    var insertingAt: InsertionPoint?
    /// Y4：在編輯頁上開的。整理好就收起來，字回到那一頁。
    var isInEditor = false
    /// 首頁原地版收起來時叫它；nil 是半頁面板，收起來用系統的 dismiss。
    var onClose: (() -> Void)?

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var phase = Phase.starting
    @State var isPulsing = false
    /// 按「繼續錄」沒成功時那一句；留在同一個畫面，等一下還能再按。
    @State var resumeFailure: String?
    /// 按了停止、正在收掉邊錄邊轉（最多一兩秒）：停止與繼續錄都不給再按（S4 審查）。
    @State var isStopping = false
    /// K6：這段錄音標了幾個重點（觸覺回饋也跟著它）。
    @State var markCount = 0
    /// 面板開著時，別處要開錄的請求先等（`RecordingLauncher`）。
    @State private var panelID = UUID()
    /// 原地版切到別的分頁再回來，畫面會重新出現；已經開錄過就不再開一次。
    @State private var hasStarted = false

    var isInline: Bool {
        onClose != nil
    }

    var body: some View {
        Group {
            if isInline {
                inlineBody
            } else {
                sheetBody
            }
        }
        .sensoryFeedbackIfEnabled(trigger: phase) { old, new in
            Self.feedback(from: old, to: new)
        }
        .task {
            guard !hasStarted else {
                return
            }
            hasStarted = true
            await startRecording()
        }
        .onAppear { RecordingLauncher.shared.panelOpened(panelID) }
        .onDisappear { RecordingLauncher.shared.panelClosed(panelID) }
        .onChange(of: recorder.isPaused) { _, paused in
            if paused {
                phase = .interrupted
            } else if recorder.isRecording {
                resumeFailure = nil
                phase = .recording
            }
        }
    }

    private var sheetBody: some View {
        VStack(spacing: Token.Space.xl) {
            phaseContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Token.Space.xl)
        .padding(.vertical, Token.Space.xl)
        .background(Token.Colors.rowBackground)
        .interactiveDismissDisabled()
    }

    /// 各階段的內容；錄音中原地版另有長相（`+Inline`）。
    @ViewBuilder
    var phaseContent: some View {
        switch phase {
        case .starting, .recording:
            if isInline {
                inlineRecordingContent
            } else {
                recordingContent
            }
        case .interrupted:
            interruptedContent
        case .microphoneDenied:
            MicrophoneDeniedContent { close() }
        case let .failed(message):
            failedContent(message)
        case let .processing(recordingURL):
            RecordingResultView(
                queue: queue,
                recordingURL: recordingURL,
                captureGaps: recorder.lastGaps,
                onOpenTranscript: onOpenTranscript,
                onOpenSettings: onOpenSettings,
                returningTo: isInEditor ? appendingTo : nil,
                onClose: onClose
            )
        }
    }

    /// 收起來：原地版回到待機，半頁面板收下去。
    func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    /// 手感參數表：開始、停止各一下且不同；失敗一下警告。整理好的那一下在 `RecordingResultView`。
    static func feedback(from old: Phase, to new: Phase) -> SensoryFeedback? {
        switch new {
        case .recording:
            Token.Haptics.recordStart
        case .processing:
            old == .recording || old == .interrupted ? Token.Haptics.recordStop : nil
        case .microphoneDenied, .failed:
            Token.Haptics.failed
        case .starting, .interrupted:
            nil
        }
    }

    @MainActor
    private func startRecording() async {
        do {
            try await recorder.start()
            phase = recorder.isPaused ? .interrupted : .recording
            isStopping = false
            if let liveURL = recorder.liveRecordingURL {
                rememberAppendTarget(for: liveURL)
                queue.startLive(recordingAt: liveURL)
            }
        } catch Recorder.Failure.microphoneDenied {
            phase = .microphoneDenied
        } catch Recorder.Failure.notEnoughSpace {
            phase = .failed("手機空間不夠，先清一點再錄。")
        } catch {
            phase = .failed("錄音沒有開始，再試一次。")
        }
    }

    @MainActor
    func resumeRecording() {
        do {
            try recorder.resume()
            resumeFailure = nil
            phase = .recording
        } catch Recorder.Failure.notEnoughSpace {
            resumeFailure = "手機空間還是不夠，清出空間再按一次。"
        } catch {
            resumeFailure = "現在還接不回去，等一下再按一次。"
        }
    }

    /// 先停收音，再收掉邊錄邊轉（它還在讀這個檔），才把檔搬進待轉錄。
    @MainActor
    func stopRecording() {
        guard !isStopping else {
            return
        }
        isStopping = true
        let recordedURL: URL
        do {
            recordedURL = try recorder.stop()
        } catch {
            Task { await queue.finishLive() }
            phase = .failed("錄音停不下來或存不進去，檔案還在，重開米說會撿回來。")
            return
        }
        Task {
            await queue.finishLive()
            do {
                let pendingURL = try PendingRecordings().accept(recordingAt: recordedURL)
                phase = .processing(pendingURL)
            } catch {
                phase = .failed("錄音停不下來或存不進去，檔案還在，重開米說會撿回來。")
            }
        }
    }

    /// 一開錄就用檔名記，不等到停止：面板被拆掉、停止時出錯，這段之後還認得要接回哪一篇。
    private func rememberAppendTarget(for recordingURL: URL) {
        if let appendingTo {
            queue.appendTargets[recordingURL.lastPathComponent] = .init(
                transcriptID: appendingTo,
                insertion: insertingAt
            )
        }
    }
}
