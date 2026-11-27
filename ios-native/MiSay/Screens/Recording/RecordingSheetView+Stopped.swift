import SwiftUI

/// 錄音面板沒在收音時的內容：被打斷、失敗。從主檔搬出來，讓它留在 300 行內。
/// 2026-11-27 B 版：被打斷時上半部照錄音中的排法，只是膠囊、計時、聲波都變灰，下面一張白卡講發生什麼；
/// 「繼續錄」「停止」在托盤。暫停只在被系統打斷時出現，沒有手動暫停鈕。
extension RecordingSheetView {
    /// 被打斷、接不回去、空間滿時：會自己接回，也可以自己按（2026-11-04 米點頭，取代 C3 的不自動續錄）。
    var interruptedContent: some View {
        RecordingTrayLayout {
            AccentCapsule(isMuted: true) {
                Image(systemName: "pause.fill")
                    .accessibilityHidden(true)
                Text("沒在收音")
            }
            RecordingTimer(recorder: recorder, isDimmed: true)
            RecordingWaveform(recorder: recorder, height: waveHeight, isDimmed: true)
            Text(Self.pausedMessage(for: recorder.pauseReason, elapsed: recorder.elapsedSeconds))
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Token.Space.l)
                .background(
                    Token.Colors.rowBackground,
                    in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow, style: .continuous)
                )
            if let resumeFailure {
                StatusStrip(glyph: .failed, message: resumeFailure)
            }
        } tray: {
            Button("繼續錄") {
                resumeRecording()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isStopping)
            Button("停止") {
                stopRecording()
            }
            .buttonStyle(TextButtonStyle())
            .disabled(isStopping)
        }
    }

    /// 開不起來或收不進去：走到這裡時已經沒在錄了，托盤只剩「完成」。
    func failedContent(_ message: String) -> some View {
        // 原因有「開不起來」也有「檔案還在、重開會撿回來」，不另外下大標，整句放在狀態條裡。
        RecordingTrayLayout {
            StatusStrip(glyph: .failed, message: message)
        } tray: {
            Button("完成") {
                close()
            }
            .buttonStyle(TextButtonStyle())
        }
    }
}
