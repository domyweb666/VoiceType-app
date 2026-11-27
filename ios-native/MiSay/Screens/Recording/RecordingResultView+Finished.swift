import SwiftUI

/// 完成（B4，2026-11-27）：大標「好了，已經複製」，下面「中間斷過幾次」那行、三行預覽白卡、要不要發通知；
/// 「打開這篇」「完成」在托盤。自動複製照舊，沒有複製鈕。
extension RecordingResultView {
    /// 在編輯頁上錄的：字回到哪裡了。接不回去（那篇剛好刪掉、正在整理、存不進去）字也在，講清楚在哪。
    static func returnedMessage(isMerged: Bool, isWaiting: Bool) -> String {
        if isMerged {
            return "剛才錄的已經放回文稿裡。"
        }
        return isWaiting
            ? "整理好了，等一下會放回文稿裡。"
            : "放不回原本那篇，另外存成一篇，在文字稿清單裡。"
    }

    func finishedStage(_ transcript: Transcript, isCopied: Bool) -> some View {
        Group {
            VStack(alignment: .leading, spacing: Token.Space.s) {
                HStack(spacing: Token.Space.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Token.Fonts.icon)
                        .foregroundStyle(Token.Colors.accent)
                        .accessibilityHidden(true)
                    Text(isCopied ? "好了，已經複製" : "好了")
                        .font(titleFont)
                        .foregroundStyle(Token.Colors.textPrimary)
                }
                gapLine
            }
            previewCard(PlainTextExport.opening(of: transcript.displayText))
            if let returningTo {
                message(Self.returnedMessage(
                    isMerged: transcript.id == returningTo,
                    isWaiting: queue.isWaitingToAppend(transcript.id)
                ))
            }
            RecordingAlarmPrompt()
        }
    }

    @ViewBuilder
    func finishedTray(_ transcript: Transcript) -> some View {
        if returningTo == nil {
            Button("打開這篇") { onOpenTranscript(transcript) }
                .buttonStyle(PrimaryButtonStyle())
        }
        Button("完成") { close() }
            .buttonStyle(TextButtonStyle())
    }

    /// 完成畫面的三行預覽（03-線框）：看得到字，想細看再「打開這篇」。B 版改白卡放在米白底上。
    func previewCard(_ text: String) -> some View {
        Text(text)
            .font(Token.Fonts.body)
            .foregroundStyle(Token.Colors.textPrimary)
            .lineLimit(Self.previewLines)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Token.Space.l)
            .background(
                Token.Colors.rowBackground,
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow, style: .continuous)
            )
    }
}
