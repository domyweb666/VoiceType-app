import SwiftUI

/// 錄音中的內容（B 版：上面看、下面按）。被打斷、失敗在 `RecordingSheetView+Stopped.swift`。
/// 上半部：「正在聽」膠囊、放大的計時、一排聲波；托盤：左「標記重點」、中停止鈕、右已標幾個。
/// 2026-11-26 從主檔搬出來，讓它留在 300 行內；2026-11-27 首頁原地版與半頁版改成同一套。
extension RecordingSheetView {
    var recordingContent: some View {
        RecordingTrayLayout {
            statusRow
            RecordingTimer(recorder: recorder)
            RecordingWaveform(recorder: recorder, height: waveHeight)
        } tray: {
            HStack(spacing: Token.Space.s) {
                markButton
                    .frame(maxWidth: .infinity)
                stopButton
                markCountLabel
                    .frame(maxWidth: .infinity)
            }
            Text("按方塊結束")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
        }
    }

    /// 左「正在聽」，右邊一句小字：平常講鎖屏也會錄，空間快不夠時換成紅字剩幾分鐘。
    private var statusRow: some View {
        HStack(spacing: Token.Space.s) {
            listeningLine
            Spacer(minLength: Token.Space.s)
            spaceNote
                .multilineTextAlignment(.trailing)
        }
    }

    private var canMark: Bool {
        guard phase == .recording else {
            return false
        }
        return !isStopping
    }

    /// K6：講到重點按一下，記下第幾秒；整理完在詳情頁「⋯ → 錄音與原稿」看得到。
    /// B 版：淡金圓裡一支旗子，字在圓下面；已標幾個搬到托盤右邊（`markCountLabel`）。
    var markButton: some View {
        Button {
            guard let name = recorder.liveRecordingURL?.lastPathComponent else {
                return
            }
            // 記不進去只是少一個標記，錄音照常；不跳錯。
            let seconds = recorder.elapsedSeconds
            if (try? RecordingMarks().add(seconds, forRecordingNamed: name)) != nil {
                markCount += 1
            }
        } label: {
            VStack(spacing: Token.Space.xs) {
                Image(systemName: "flag")
                    .font(Token.Fonts.icon)
                    .frame(width: Token.Shape.markCircle, height: Token.Shape.markCircle)
                    .background(Token.Colors.accentSoft, in: Circle())
                Text("標記重點")
                    .font(Token.Fonts.footnote.weight(.semibold))
            }
            .foregroundStyle(Token.Colors.link)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(canMark ? 1 : Token.Motion.disabledOpacity)
        .disabled(!canMark)
        .accessibilityLabel(markCount == 0 ? "標記重點" : "標記重點，已標 \(markCount) 個")
        .sensoryFeedbackIfEnabled(Token.Haptics.copied, trigger: markCount)
    }

    /// 托盤右邊：已經標了幾個重點。讀屏從標記鈕就聽得到，這裡不再唸一次。
    private var markCountLabel: some View {
        VStack(spacing: Token.Space.xs) {
            Text("\(markCount)")
                .font(Token.Fonts.sectionTitle.weight(.bold))
                .foregroundStyle(Token.Colors.textPrimary)
            Text("已標重點")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityHidden(true)
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

    /// 80pt 金棕鈕（domy：進行中用產品色實心＋方塊）；外圈淡金線 1.4 秒呼吸一次（88 → 104）。
    /// 減少動態時外圈停在 104 不動，圓點本來就在「正在聽」旁邊。
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
                    Circle()
                        .stroke(
                            Token.Colors.recordingFill.opacity(Token.Halo.stopRingOpacity),
                            lineWidth: Token.Shape.stopRingLine
                        )
                        .padding(isPulsing || reduceMotion ? -Token.Space.m : -Token.Space.xs)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
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
