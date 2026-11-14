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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 計時字級跟著系統字級放大（使用規則第 5 條）。
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = Token.Fonts.timerSize
    @State private var phase = Phase.starting
    @State private var isPulsing = false
    /// 按「繼續錄」沒成功時那一句；留在同一個畫面，等一下還能再按。
    @State private var resumeFailure: String?
    /// 按了停止、正在收掉邊錄邊轉（最多一兩秒）：停止與繼續錄都不給再按（S4 審查）。
    @State private var isStopping = false
    /// K6：這段錄音標了幾個重點（觸覺回饋也跟著它）。
    @State private var markCount = 0

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
                    onOpenSettings: onOpenSettings
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
    private func resumeRecording() {
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
    private func stopRecording() {
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
                if let appendingTo {
                    queue.appendTargets[pendingURL.lastPathComponent] = .init(
                        transcriptID: appendingTo,
                        insertion: insertingAt
                    )
                }
                phase = .processing(pendingURL)
            } catch {
                phase = .failed("錄音停不下來或存不進去，檔案還在，重開米說會撿回來。")
            }
        }
    }
}

/// 錄音前半段的內容：錄音中、被打斷、失敗。
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

    /// K6：講到重點按一下，記下第幾秒；整理完在詳情頁「⋯ → 聽原音與重點」看得到。
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
            RoundedRectangle(cornerRadius: Token.Shape.radiusStopGlyph)
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

    /// 被打斷、接不回去、空間滿時：會自己接回，也可以自己按（2026-11-04 米點頭，取代 C3 的不自動續錄）。
    var interruptedContent: some View {
        VStack(spacing: Token.Space.m) {
            IconCircle(systemName: "pause.fill")
            Text(Self.pausedMessage(for: recorder.pauseReason, elapsed: recorder.elapsedSeconds))
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Spacer(minLength: Token.Space.s)
            Button("繼續錄") {
                resumeRecording()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isStopping)
            if let resumeFailure {
                Text(resumeFailure)
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.danger)
                    .multilineTextAlignment(.center)
            }
            Button("停止") {
                stopRecording()
            }
            .buttonStyle(TextButtonStyle())
            .disabled(isStopping)
        }
    }

    /// 開不起來或收不進去：走到這裡時已經沒在錄了，只剩「完成」。
    func failedContent(_ message: String) -> some View {
        VStack(spacing: Token.Space.m) {
            IconCircle.failure
            Text(message)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Spacer(minLength: Token.Space.s)
            Button("完成") {
                dismiss()
            }
            .buttonStyle(TextButtonStyle())
        }
    }
}
