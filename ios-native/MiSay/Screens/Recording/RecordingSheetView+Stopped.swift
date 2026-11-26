import SwiftUI

/// 錄音面板沒在收音時的內容：被打斷、失敗。從主檔搬出來，讓它留在 300 行內。
extension RecordingSheetView {
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
                close()
            }
            .buttonStyle(TextButtonStyle())
        }
    }
}
