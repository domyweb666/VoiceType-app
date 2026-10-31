import SwiftUI

/// 錄音面板（半頁模態，不可下滑關閉：03-線框「錄到一半誤滑就丟掉」）。
/// 片 C1：錄音中、失敗、停止；片 C2：麥克風被拒；片 C3：被來電打斷。整理中、完成、沒聲音是 D6。
struct RecordingSheetView: View {
    enum Phase: Equatable {
        case starting
        case recording
        case stopped
        case interrupted
        case microphoneDenied
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recorder = Recorder()
    @State private var phase = Phase.starting
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: Token.Space.xl) {
            switch phase {
            case .starting, .recording, .stopped:
                recordingContent
            case .interrupted:
                interruptedContent
            case .microphoneDenied:
                deniedContent
            case let .failed(message):
                failedContent(message)
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
        .onChange(of: recorder.isInterrupted) { _, interrupted in
            if interrupted {
                phase = .interrupted
            }
        }
    }

    /// 手感參數表：開始、停止各一下且不同；失敗一下警告。
    static func feedback(from old: Phase, to new: Phase) -> SensoryFeedback? {
        switch new {
        case .recording:
            return Token.Haptics.recordStart
        case .stopped:
            return old == .recording ? Token.Haptics.recordStop : nil
        case .microphoneDenied, .failed:
            return Token.Haptics.failed
        case .starting, .interrupted:
            return nil
        }
    }

    /// 片 C3：來電等中斷結束後，由使用者決定續錄還是收檔（首次體驗檔「被打斷回來」那一列）。
    private var interruptedContent: some View {
        VStack(spacing: Token.Space.m) {
            Text("通話時暫停了，已錄到的 \(Self.formatSpoken(recorder.elapsedSeconds)) 都在。")
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
            Button("停止") {
                stopRecording()
            }
            .font(Token.Fonts.body)
            .tint(Token.Colors.link)
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

    private var recordingContent: some View {
        VStack(spacing: Token.Space.m) {
            Text(Self.formatElapsed(recorder.elapsedSeconds))
                .font(Token.Fonts.timer)
                .foregroundStyle(Token.Colors.textPrimary)
                .accessibilityLabel("已錄 \(Self.formatElapsed(recorder.elapsedSeconds))")
            Text("正在聽")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
            waveform
            HStack(spacing: Token.Space.m) {
                if reduceMotion {
                    Circle()
                        .fill(Token.Colors.recordingFill)
                        .frame(width: Token.Space.s, height: Token.Space.s)
                        .accessibilityHidden(true)
                }
                stopButton
            }
            Text("鎖住螢幕也會繼續錄")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
        }
    }

    /// 減少動態時不畫一排會跳的柱子，改成一條固定位置的音量條（手感參數表）。
    @ViewBuilder
    private var waveform: some View {
        if reduceMotion {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: Token.Space.xs)
                    .fill(Token.Colors.waveform)
                    .frame(width: geometry.size.width * recorder.level)
            }
            .frame(height: Token.Space.s)
            .accessibilityHidden(true)
        } else {
            HStack(alignment: .center, spacing: Token.Space.xs) {
                ForEach(Array(recorder.levels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: Token.Space.xs)
                        .fill(Token.Colors.waveform)
                        .frame(
                            width: Token.Space.xs,
                            height: max(Token.Space.xs, Token.Shape.primaryTap * level)
                        )
                }
            }
            .frame(height: Token.Shape.primaryTap)
            .accessibilityHidden(true)
        }
    }

    /// 80pt 紅鈕；外圈 1.4 秒呼吸一次（4pt → 12pt）。減少動態時不呼吸，由旁邊的紅點代替。
    private var stopButton: some View {
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
    }

    /// 片 C2：文案照首次體驗檔權限時刻表；「打開『設定』」直接開系統設定的米說頁。
    private var deniedContent: some View {
        VStack(spacing: Token.Space.m) {
            Text("米說聽不到你的聲音")
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            Text("麥克風權限是關的。到『設定』打開米說的麥克風，回來就能錄。")
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
                dismiss()
            } label: {
                Text("打開『設定』")
                    .font(Token.Fonts.rowTitle)
                    .frame(maxWidth: .infinity, minHeight: Token.Shape.primaryTap)
            }
            .buttonStyle(.borderedProminent)
            .tint(Token.Colors.link)
            Button("先不要") {
                dismiss()
            }
            .font(Token.Fonts.body)
            .tint(Token.Colors.link)
        }
    }

    private func failedContent(_ message: String) -> some View {
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

    @MainActor
    private func startRecording() async {
        do {
            try await recorder.start()
            phase = .recording
        } catch Recorder.Failure.microphoneDenied {
            phase = .microphoneDenied
        } catch {
            phase = .failed("錄音沒有開始，再試一次。")
        }
    }

    @MainActor
    private func resumeRecording() {
        do {
            try recorder.resume()
            phase = .recording
        } catch {
            phase = .failed("接不回去了。已錄到的都在，按停止會收進待轉錄。")
        }
    }

    @MainActor
    private func stopRecording() {
        do {
            let recordedURL = try recorder.stop()
            _ = try PendingRecordings().accept(recordingAt: recordedURL)
            phase = .stopped
            dismiss()
        } catch {
            phase = .failed("錄音停不下來或存不進去，檔案還在，重開米說會撿回來。")
        }
    }
}
