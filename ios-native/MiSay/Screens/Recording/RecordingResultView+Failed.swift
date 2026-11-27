import SwiftUI

/// 沒整理好的結局（B 版沒畫，照 B 的排法放）：上半部講錄音在哪、原因放狀態條；鈕在托盤。
/// 2026-11-27 從主檔搬出來，讓它留在 300 行內。
extension RecordingResultView {
    var noAPIKeyStage: some View {
        Group {
            IconCircle(systemName: "key.fill", tint: Token.Colors.link)
            Text("錄音收好了，在待轉錄。")
                .font(Token.Fonts.sectionTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            gapLine
            message("設定金鑰後會自動整理。")
        }
    }

    @ViewBuilder
    var noAPIKeyTray: some View {
        if returningTo == nil {
            Button("去設定金鑰") { onOpenSettings() }
                .buttonStyle(PrimaryButtonStyle())
        }
        Button("完成") { close() }
            .buttonStyle(TextButtonStyle())
    }

    /// `lead` 講錄音還在不在、有沒有扣款；原因用狀態條。潤飾失敗那幾種沒有 `lead`，一句話就講完。
    func failedStage(lead: String?, reason: String) -> some View {
        Group {
            if let lead {
                Text(lead)
                    .font(Token.Fonts.sectionTitle)
                    .foregroundStyle(Token.Colors.textPrimary)
            }
            gapLine
            StatusStrip(glyph: .failed, message: reason)
        }
    }

    /// 錯誤第二句講原因（06-首次體驗「錯誤」列）；只有金鑰的問題才給「去設定」。
    @ViewBuilder
    func retryTray(needsNewKey: Bool) -> some View {
        Button("重試") { process() }
            .buttonStyle(PrimaryButtonStyle())
        if needsNewKey, returningTo == nil {
            Button("去設定") { onOpenSettings() }
                .buttonStyle(TextButtonStyle())
        }
        Button("完成") { close() }
            .buttonStyle(TextButtonStyle())
    }

    @ViewBuilder
    func polishFailedTray(_ transcript: Transcript) -> some View {
        Button("再試一次") { retryPolish(transcript) }
            .buttonStyle(PrimaryButtonStyle())
        if returningTo == nil {
            Button("打開這篇") { onOpenTranscript(transcript) }
                .buttonStyle(TextButtonStyle())
        }
        Button("完成") { close() }
            .buttonStyle(TextButtonStyle())
    }

    /// 不刪的話下一輪會再整理一次這段錄音，所以叫使用者自己去待轉錄刪。
    @ViewBuilder
    func recordingNotDeletedTray(_ transcript: Transcript) -> some View {
        if returningTo == nil {
            Button("打開這篇") { onOpenTranscript(transcript) }
                .buttonStyle(PrimaryButtonStyle())
        }
        Button("完成") { close() }
            .buttonStyle(TextButtonStyle())
    }
}
