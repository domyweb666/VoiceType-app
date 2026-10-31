import SwiftUI

/// 錄音面板（半頁模態，不可下滑關閉：03-線框「錄到一半誤滑就丟掉」）。
/// 片 C1：只有錄音中與失敗兩種狀態；停止後直接收起。整理中、完成、沒聲音是 D6。
struct RecordingSheetView: View {
    enum Phase: Equatable {
        case starting
        case recording
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recorder = Recorder()
    @State private var phase = Phase.starting
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: Token.Space.xl) {
            switch phase {
            case .starting, .recording:
                recordingContent
            case let .failed(message):
                failedContent(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Token.Space.l)
        .background(Token.Colors.groupedBackground)
        .interactiveDismissDisabled()
        .sensoryFeedback(trigger: phase) { old, new in
            if new == .recording {
                return Token.Haptics.recordStart
            }
            return old == .recording ? Token.Haptics.recordStop : nil
        }
        .task { await startRecording() }
    }

    private var recordingContent: some View {
        VStack(spacing: Token.Space.m) {
            Text(Self.formatElapsed(recorder.elapsedSeconds))
                .font(Token.Fonts.timer)
                .foregroundStyle(Token.Colors.textPrimary)
                .accessibilityLabel("已錄 \(Self.formatElapsed(recorder.elapsedSeconds))")
            HStack(spacing: Token.Space.s) {
                if reduceMotion {
                    Circle()
                        .fill(Token.Colors.recordingFill)
                        .frame(width: Token.Space.s, height: Token.Space.s)
                        .accessibilityHidden(true)
                }
                Text("正在聽")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
            waveform
            stopButton
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

    /// 80pt 紅鈕；外圈 1.4 秒呼吸一次（4pt → 12pt）。減少動態時不呼吸，由上面的紅點代替。
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
            // 被拒的完整畫面（「打開設定」那顆）是片 C2；這裡先用首次體驗檔的第一句。
            phase = .failed("米說聽不到你的聲音。麥克風權限是關的。")
        } catch {
            phase = .failed("錄音沒有開始，再試一次。")
        }
    }

    @MainActor
    private func stopRecording() {
        do {
            let recordedURL = try recorder.stop()
            _ = try PendingRecordings().accept(recordingAt: recordedURL)
            dismiss()
        } catch {
            phase = .failed("錄音停不下來或存不進去，檔案還在，重開米說會撿回來。")
        }
    }
}
