import SwiftUI

/// 錄音面板（半頁模態，不可下滑關閉：03-線框「錄到一半誤滑就丟掉」）。
/// 片 C1：錄音中、失敗、停止；片 C2：麥克風被拒；片 D6：停止後交給 `RecordingResultView`。
/// 組塊 S：錄音狀態在 App 層的 `Recorder`，這裡只讀；被打斷時換字，接回來就換回去。
/// 2026-11-07 統一風格：面板白底、計時 56、「正在聽」帶紅點、主要按鈕玉米黃膠囊、文字鈕金色；
/// 給人唸的字串搬到 `RecordingSheetView+Text.swift`。
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

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 計時字級跟著系統字級放大（使用規則第 5 條）。
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = Token.Fonts.timerSize
    @State private var phase = Phase.starting
    @State private var isPulsing = false
    /// 按「繼續錄」沒成功時那一句；留在同一個畫面，等一下還能再按。
    @State var resumeFailure: String?
    /// 按了停止、正在收掉邊錄邊轉（最多一兩秒）：停止與繼續錄都不給再按（S4 審查）。
    @State var isStopping = false
    /// K6：這段錄音標了幾個重點（觸覺回饋也跟著它）。
    @State private var markCount = 0
    /// 面板開著時，別處要開錄的請求先等（`RecordingLauncher`）。
    @State private var panelID = UUID()

    var body: some View {
        VStack(spacing: Token.Space.xl) {
            switch phase {
            case .starting, .recording:
                recordingContent
            case .interrupted:
                interruptedContent
            case .microphoneDenied:
                MicrophoneDeniedContent { dismiss() }
            case let .failed(message):
                failedContent(message)
            case let .processing(recordingURL):
                RecordingResultView(
                    queue: queue,
                    recordingURL: recordingURL,
                    captureGaps: recorder.lastGaps,
                    onOpenTranscript: onOpenTranscript,
                    onOpenSettings: onOpenSettings,
                    returningTo: isInEditor ? appendingTo : nil
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Token.Space.xl)
        .padding(.vertical, Token.Space.xl)
        .background(Token.Colors.rowBackground)
        .interactiveDismissDisabled()
        .sensoryFeedback(trigger: phase) { old, new in
            Self.feedback(from: old, to: new)
        }
        .task { await startRecording() }
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

/// 錄音中的內容。被打斷、失敗在 `RecordingSheetView+Stopped.swift`。
private extension RecordingSheetView {
    var recordingContent: some View {
        VStack(spacing: Token.Space.m) {
            Text(Self.formatElapsed(recorder.elapsedSeconds))
                .font(Token.Fonts.timer(timerSize))
                .foregroundStyle(Token.Colors.textPrimary)
                .accessibilityLabel("已錄 \(Self.formatElapsed(recorder.elapsedSeconds))")
            listeningLine
            Spacer(minLength: Token.Space.s)
            RecordingWaveform(recorder: recorder)
            Spacer(minLength: Token.Space.s)
            stopButton
            markButton
            spaceNote
        }
    }

    /// K6：講到重點按一下，記下第幾秒；整理完在詳情頁「⋯ → 錄音與原稿」看得到。
    var markButton: some View {
        Button(markCount == 0 ? "標記重點" : "標記重點（已標 \(markCount) 個）") {
            guard let name = recorder.liveRecordingURL?.lastPathComponent else {
                return
            }
            // 記不進去只是少一個標記，錄音照常；不跳錯。
            let seconds = recorder.elapsedSeconds
            if (try? RecordingMarks().add(seconds, forRecordingNamed: name)) != nil {
                markCount += 1
            }
        }
        .buttonStyle(TextButtonStyle())
        .disabled(phase != .recording || isStopping)
        .sensoryFeedback(Token.Haptics.copied, trigger: markCount)
    }

    /// 錄音中＝圓點＋計時在跳＋「正在聽」三樣一起（使用規則第 4 條）。
    /// 2026-11-14 照 domy 的錄音畫面：圓點和字一起放進淡金膠囊，圓點用金棕不用紅。
    var listeningLine: some View {
        AccentCapsule {
            Circle()
                .fill(Token.Colors.recordingFill)
                .frame(width: Token.Space.s, height: Token.Space.s)
                .accessibilityHidden(true)
            Text(recorder.isWaitingForSound ? "接回去了，還沒聽到聲音" : "正在聽")
        }
    }

    @ViewBuilder
    var spaceNote: some View {
        if let minutes = recorder.minutesLeftOnDisk {
            Text("手機空間只夠再錄約 \(minutes) 分鐘")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.danger)
        } else {
            Text("鎖住螢幕也會繼續錄")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
        }
    }

    /// 80pt 金棕鈕（domy：進行中用產品色實心＋方塊）；外圈 1.4 秒呼吸一次（4pt → 12pt）。
    /// 減少動態時不呼吸，圓點本來就在「正在聽」旁邊。
    var stopButton: some View {
        Button {
            stopRecording()
        } label: {
            RoundedRectangle(cornerRadius: Token.Shape.radiusStopGlyph, style: .continuous)
                .fill(Token.Colors.recordingGlyph)
                .frame(width: Token.Shape.stopGlyph, height: Token.Shape.stopGlyph)
                .frame(width: Token.Shape.stopTap, height: Token.Shape.stopTap)
                .background(Token.Colors.recordingFill, in: Circle())
                .background {
                    if !reduceMotion {
                        Circle()
                            .stroke(Token.Colors.recordingFill)
                            .padding(isPulsing ? -Token.Space.m : -Token.Space.xs)
                    }
                }
        }
        .accessibilityLabel("停止錄音")
        .disabled(phase != .recording || isStopping)
        .onAppear {
            guard !reduceMotion else {
                return
            }
            let breathing = Animation.easeInOut(duration: Token.Motion.recordingPulse)
            withAnimation(breathing.repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        // 被打斷再接回時這顆鈕會重新出現；不歸零的話值沒變，外圈就不再呼吸。
        .onDisappear { isPulsing = false }
    }
}
