import SwiftUI

/// 錄音面板（半頁模態，不可下滑關閉：03-線框「錄到一半誤滑就丟掉」）。
/// 片 C1：錄音中、失敗、停止；片 C2：麥克風被拒；片 D6：停止後交給 `RecordingResultView`。
/// 組塊 S：錄音狀態在 App 層的 `Recorder`，這裡只讀；被打斷時換字，接回來就換回去。
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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.starting
    @State private var isPulsing = false
    /// 按「繼續錄」沒成功時那一句；留在同一個畫面，等一下還能再按。
    @State private var resumeFailure: String?

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
        .padding(.horizontal, Token.Space.l)
        .background(Token.Colors.groupedBackground)
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

    /// 給人唸的：「2 分 17 秒」；不到一分鐘「17 秒」；超過一小時「1 小時 2 分 17 秒」。
    static func formatSpoken(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours) 小時")
        }
        if minutes > 0 {
            parts.append("\(minutes) 分")
        }
        parts.append("\(secs) 秒")
        return parts.joined(separator: " ")
    }

    /// 「02:17」；超過一小時「1:02:17」。
    static func formatElapsed(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// 沒在收音時那一句。第一句回答有沒有損失之前先講發生什麼，因為使用者是回頭才看到這裡。
    static func pausedMessage(for reason: Recorder.PauseReason?, elapsed: Double) -> String {
        let saved = "已錄到的 \(formatSpoken(elapsed)) 都在。"
        switch reason {
        case .outOfSpace:
            return "手機空間快滿了，先停了。\(saved)清出空間可以按繼續錄。"
        case .lostInput:
            return "收音斷了，正在接回去。\(saved)"
        case .interrupted, nil:
            return "被打斷了，結束後會自己接回去。\(saved)"
        }
    }

    /// 完成面板那一行；沒斷過是 nil。
    static func gapText(for gaps: CaptureWatch.Gaps) -> String? {
        guard gaps.times > 0 else {
            return nil
        }
        let length = gaps.seconds < 1 ? "不到 1 秒" : formatSpoken(gaps.seconds)
        return "中間斷過 \(gaps.times) 次，共 \(length)。"
    }

    @MainActor
    private func startRecording() async {
        do {
            try await recorder.start()
            phase = recorder.isPaused ? .interrupted : .recording
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

    @MainActor
    private func stopRecording() {
        do {
            let recordedURL = try recorder.stop()
            let pendingURL = try PendingRecordings().accept(recordingAt: recordedURL)
            phase = .processing(pendingURL)
        } catch {
            phase = .failed("錄音停不下來或存不進去，檔案還在，重開米說會撿回來。")
        }
    }
}

/// 錄音前半段的內容：錄音中、被打斷、失敗。
private extension RecordingSheetView {
    var recordingContent: some View {
        VStack(spacing: Token.Space.m) {
            Text(Self.formatElapsed(recorder.elapsedSeconds))
                .font(Token.Fonts.timer)
                .foregroundStyle(Token.Colors.textPrimary)
                .accessibilityLabel("已錄 \(Self.formatElapsed(recorder.elapsedSeconds))")
            Text(recorder.isWaitingForSound ? "接回去了，還沒聽到聲音" : "正在聽")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
            RecordingWaveform(recorder: recorder)
            HStack(spacing: Token.Space.m) {
                if reduceMotion {
                    Circle()
                        .fill(Token.Colors.recordingFill)
                        .frame(width: Token.Space.s, height: Token.Space.s)
                        .accessibilityHidden(true)
                }
                stopButton
            }
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
    }

    /// 80pt 紅鈕；外圈 1.4 秒呼吸一次（4pt → 12pt）。減少動態時不呼吸，由旁邊的紅點代替。
    var stopButton: some View {
        Button {
            stopRecording()
        } label: {
            Image(systemName: "stop.fill")
                .font(Token.Fonts.largeTitle)
                .foregroundStyle(Token.Colors.recordingGlyph)
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
        .disabled(phase != .recording)
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
            Text(Self.pausedMessage(for: recorder.pauseReason, elapsed: recorder.elapsedSeconds))
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                resumeRecording()
            } label: {
                Text("繼續錄")
                    .font(Token.Fonts.rowTitle)
                    .frame(maxWidth: .infinity, minHeight: Token.Shape.primaryTap)
            }
            .buttonStyle(.borderedProminent)
            .tint(Token.Colors.link)
            if let resumeFailure {
                Text(resumeFailure)
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.danger)
                    .multilineTextAlignment(.center)
            }
            Button("停止") {
                stopRecording()
            }
            .font(Token.Fonts.body)
            .tint(Token.Colors.link)
        }
    }

    /// 開不起來或收不進去：走到這裡時已經沒在錄了，只剩「完成」。
    func failedContent(_ message: String) -> some View {
        VStack(spacing: Token.Space.m) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(Token.Fonts.largeTitle)
                .foregroundStyle(Token.Colors.danger)
                .accessibilityHidden(true)
            Text(message)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Button("完成") {
                dismiss()
            }
            .font(Token.Fonts.body)
            .tint(Token.Colors.link)
        }
    }
}
