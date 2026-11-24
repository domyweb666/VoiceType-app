import SwiftUI

/// 完成面板後面兩種結局：整理好了、錄音刪不掉。從主檔搬出來，讓它留在 300 行內。
extension RecordingResultView {
    /// 不刪的話下一輪會再整理一次這段錄音，所以叫使用者自己去待轉錄刪。
    func recordingNotDeletedContent(_ transcript: Transcript) -> some View {
        VStack(spacing: Token.Space.m) {
            failureIcon
            message("口語稿已經存好，但錄音檔刪不掉，還在待轉錄。到待轉錄把它刪掉，不然會再整理一次。")
            Spacer(minLength: Token.Space.s)
            if returningTo == nil {
                Button("打開這篇") { onOpenTranscript(transcript) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            Button("完成") { dismiss() }
                .buttonStyle(TextButtonStyle())
        }
    }

    /// 在編輯頁上錄的：字回到哪裡了。接不回去（那篇剛好刪掉、正在整理、存不進去）字也在，講清楚在哪。
    static func returnedMessage(isMerged: Bool, isWaiting: Bool) -> String {
        if isMerged {
            return "剛才錄的已經放回文稿裡。"
        }
        return isWaiting
            ? "整理好了，等一下會放回文稿裡。"
            : "放不回原本那篇，另外存成一篇，在文字稿清單裡。"
    }

    func finishedContent(_ transcript: Transcript, isCopied: Bool) -> some View {
        VStack(spacing: Token.Space.m) {
            HStack(spacing: Token.Space.s) {
                Image(systemName: "checkmark.circle.fill")
                    .font(Token.Fonts.icon)
                    .foregroundStyle(Token.Colors.accent)
                    .accessibilityHidden(true)
                Text(isCopied ? "好了，已經複製" : "好了")
                    .font(Token.Fonts.sectionTitle)
                    .foregroundStyle(Token.Colors.textPrimary)
            }
            previewCard(transcript.displayText)
            if let returningTo {
                message(Self.returnedMessage(
                    isMerged: transcript.id == returningTo,
                    isWaiting: queue.isWaitingToAppend(transcript.id)
                ))
            } else {
                Button("打開這篇") { onOpenTranscript(transcript) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            Button("完成") { dismiss() }
                .buttonStyle(TextButtonStyle())
            Spacer(minLength: Token.Space.xs)
            RecordingAlarmPrompt()
        }
    }

    /// 完成面板的三行預覽（03-線框）：看得到字，想細看再「打開這篇」。
    func previewCard(_ text: String) -> some View {
        Text(text)
            .font(Token.Fonts.secondary)
            .foregroundStyle(Token.Colors.textPrimary)
            .lineLimit(Self.previewLines)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Token.Space.l)
            .background(
                Token.Colors.sunkenBackground,
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow, style: .continuous)
            )
    }
}
