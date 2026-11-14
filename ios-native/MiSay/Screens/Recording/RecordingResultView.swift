import SwiftUI

/// 錄音面板的後半段（片 D6）：停止之後的整理中、完成、失敗、沒金鑰、潤飾失敗。文案照 06-首次體驗「錄音面板」。
/// 整理跑在不跟畫面綁的 Task 裡：按「收起來」收起面板，流水照樣在背景跑完；錄音檔在口語稿存好前都在待轉錄。
/// 完成面板「收成第 N 根」的位置留在「好了」那行下面，穀倉還沒做，不畫。
/// 2026-11-07 統一風格：完成面板多三行文字稿預覽；純判斷搬到 `RecordingResultView+Status.swift`。
struct RecordingResultView: View {
    enum Status: Equatable {
        case processing
        case noAPIKey
        case transcriptionFailed(reason: String, needsNewKey: Bool)
        case storageFailed
        case polishFailed(Transcript)
        /// 潤飾好了但文字稿存不進去：再按一次會重新潤飾、再算一次錢，所以跟潤飾失敗分開講。
        case draftNotSaved(Transcript)
        case recordingNotDeleted(Transcript)
        case finished(Transcript, isCopied: Bool)
    }

    /// 完成面板預覽幾行（03-線框）。
    static let previewLines = 3

    let queue: TranscriptionQueue
    let recordingURL: URL
    let captureGaps: CaptureWatch.Gaps
    let onOpenTranscript: (Transcript) -> Void
    let onOpenSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status = Status.processing
    @State private var hasStarted = false
    @State private var isShown = true
    /// 第一次整理才出現的費用說明；開始時記下來，不然一設成看過就馬上消失。
    @State private var showsCostNotice = !AppSettings.shared.hasSeenCostNotice

    var body: some View {
        VStack(spacing: Token.Space.m) {
            if let gapText = RecordingSheetView.gapText(for: captureGaps) {
                message(gapText)
            }
            switch status {
            case .processing:
                processingContent
            case .noAPIKey:
                noAPIKeyContent
            case let .transcriptionFailed(reason, needsNewKey):
                failedContent(
                    lead: "錄音還在待轉錄，沒有被扣款。",
                    reason: reason,
                    needsNewKey: needsNewKey
                )
            case .storageFailed:
                // 這時已經轉好、已經扣款，所以不說「沒有被扣款」。
                failedContent(
                    lead: "錄音還在待轉錄。",
                    reason: "口語稿存不進去，再試一次。",
                    needsNewKey: false
                )
            case let .polishFailed(transcript):
                polishFailedContent(transcript, message: "口語稿已經存好，潤飾沒有成功。")
            case let .draftNotSaved(transcript):
                polishFailedContent(
                    transcript,
                    message: "口語稿已經存好，文字稿存不進去。再試一次會重新潤飾。"
                )
            case let .recordingNotDeleted(transcript):
                recordingNotDeletedContent(transcript)
            case let .finished(transcript, isCopied):
                finishedContent(transcript, isCopied: isCopied)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(trigger: status) { _, new in
            Self.feedback(for: new)
        }
        .onAppear {
            guard !hasStarted else {
                return
            }
            hasStarted = true
            process()
        }
        .onDisappear { isShown = false }
    }

    private func process() {
        status = .processing
        Task { @MainActor in
            let outcome = await queue.process(recordingAt: recordingURL)
            apply(outcome)
        }
    }

    private func retryPolish(_ transcript: Transcript) {
        status = .processing
        Task { @MainActor in
            let outcome = await queue.retryPolish(transcript)
            apply(outcome)
        }
    }

    private func apply(_ outcome: TranscriptionQueue.Outcome?) {
        // 費用說明要等真的送出去過才算看過：沒金鑰時面板一閃就換掉，不能算。
        if let outcome, outcome != .noAPIKey {
            AppSettings.shared.hasSeenCostNotice = true
        }
        switch outcome {
        case nil:
            // 背景那一輪已經在整理這一筆，交給它；面板收起，好了會出現在文字稿。
            dismiss()
        case .noAPIKey:
            status = .noAPIKey
        case let .transcriptionFailed(failure):
            status = Self.failedStatus(for: failure)
        case .storageFailed:
            status = .storageFailed
        case .recordingUnreadable:
            status = .transcriptionFailed(reason: "這段錄音讀不出來，再試一次。", needsNewKey: false)
        case let .recordingNotDeleted(transcript):
            status = .recordingNotDeleted(transcript)
        case let .polishFailed(transcript, _):
            status = .polishFailed(transcript)
        case let .draftNotSaved(transcript):
            status = .draftNotSaved(transcript)
        case let .finished(transcript):
            status = .finished(transcript, isCopied: copyIfWanted(transcript))
        }
    }

    /// 面板已經收起（按了「收起來」）就不動剪貼簿：使用者可能正在別處複製東西。
    private func copyIfWanted(_ transcript: Transcript) -> Bool {
        guard isShown, AppSettings.shared.autoCopy else {
            return false
        }
        UIPasteboard.general.string = transcript.displayText
        return true
    }
}

/// 各狀態的內容。主要動作玉米黃膠囊、其他文字鈕金色（使用規則第 2、11 條）。
private extension RecordingResultView {
    var processingContent: some View {
        VStack(spacing: Token.Space.m) {
            spinner
            Text("整理中…")
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            if let segment = Self.segmentText(
                for: queue.activity,
                recording: recordingURL.lastPathComponent
            ) {
                Text(segment)
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
            if showsCostNotice {
                Text("錄音會送到 OpenAI 轉成文字，費用算在你的金鑰上")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            // S2-8：原本「先放著」聽起來像放著就會好，其實鎖屏太久會停。照實講。
            Text("收起來也會繼續整理；鎖屏太久會先停，回到米說接著做。")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: Token.Space.s)
            Button("收起來") { dismiss() }
                .buttonStyle(TextButtonStyle())
        }
    }

    var noAPIKeyContent: some View {
        VStack(spacing: Token.Space.m) {
            IconCircle(systemName: "key.fill", tint: Token.Colors.link)
            Text("錄音收好了，在待轉錄。")
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            message("設定金鑰後會自動整理。")
            Spacer(minLength: Token.Space.s)
            Button("去設定金鑰") { onOpenSettings() }
                .buttonStyle(PrimaryButtonStyle())
            Button("完成") { dismiss() }
                .buttonStyle(TextButtonStyle())
        }
    }

    func failedContent(lead: String, reason: String, needsNewKey: Bool) -> some View {
        VStack(spacing: Token.Space.m) {
            failureIcon
            Text(lead)
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
                .multilineTextAlignment(.center)
            message(reason)
            Spacer(minLength: Token.Space.s)
            Button("重試") { process() }
                .buttonStyle(PrimaryButtonStyle())
            if needsNewKey {
                Button("去設定") { onOpenSettings() }
                    .buttonStyle(TextButtonStyle())
            }
            Button("完成") { dismiss() }
                .buttonStyle(TextButtonStyle())
        }
    }

    func polishFailedContent(_ transcript: Transcript, message text: String) -> some View {
        VStack(spacing: Token.Space.m) {
            failureIcon
            message(text)
            Spacer(minLength: Token.Space.s)
            Button("再試一次") { retryPolish(transcript) }
                .buttonStyle(PrimaryButtonStyle())
            Button("打開這篇") { onOpenTranscript(transcript) }
                .buttonStyle(TextButtonStyle())
            Button("完成") { dismiss() }
                .buttonStyle(TextButtonStyle())
        }
    }

    /// 不刪的話下一輪會再整理一次這段錄音，所以叫使用者自己去待轉錄刪。
    func recordingNotDeletedContent(_ transcript: Transcript) -> some View {
        VStack(spacing: Token.Space.m) {
            failureIcon
            message("口語稿已經存好，但錄音檔刪不掉，還在待轉錄。到待轉錄把它刪掉，不然會再整理一次。")
            Spacer(minLength: Token.Space.s)
            Button("打開這篇") { onOpenTranscript(transcript) }
                .buttonStyle(PrimaryButtonStyle())
            Button("完成") { dismiss() }
                .buttonStyle(TextButtonStyle())
        }
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
            Button("打開這篇") { onOpenTranscript(transcript) }
                .buttonStyle(PrimaryButtonStyle())
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
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow)
            )
    }

    /// 跟 `IconCircle` 同一個淡金圓（domy 的空狀態圖示），裡面轉圈。
    var spinner: some View {
        ProgressView()
            .tint(Token.Colors.accent)
            .frame(width: Token.Shape.iconCircle, height: Token.Shape.iconCircle)
            .background(Token.Colors.accentSoft, in: Circle())
    }

    var failureIcon: some View {
        IconCircle.failure
    }

    func message(_ text: String) -> some View {
        Text(text)
            .font(Token.Fonts.secondary)
            .foregroundStyle(Token.Colors.textPrimary)
            .multilineTextAlignment(.center)
    }
}
