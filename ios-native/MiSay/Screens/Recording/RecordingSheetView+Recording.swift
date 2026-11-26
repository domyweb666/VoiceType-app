import SwiftUI

/// 錄音中的內容（半頁面板版；首頁原地版在 `+Inline`）。被打斷、失敗在 `RecordingSheetView+Stopped.swift`。
/// 2026-11-26 從主檔搬出來，讓它留在 300 行內。
extension RecordingSheetView {
    var recordingContent: some View {
        VStack(spacing: Token.Space.m) {
            RecordingTimer(recorder: recorder)
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
        .sensoryFeedbackIfEnabled(Token.Haptics.copied, trigger: markCount)
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
