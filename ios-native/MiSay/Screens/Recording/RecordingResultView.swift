import SwiftUI

/// 錄音面板的後半段（片 D6）：停止之後的整理中、完成、失敗、沒金鑰、潤飾失敗。文案照 06-首次體驗「錄音面板」。
/// 整理跑在不跟畫面綁的 Task 裡：按「先放著」收起面板，流水照樣在背景跑完；錄音檔在口語稿存好前都在待轉錄。
/// 完成面板「收成第 N 根」的位置留在「好了」那行下面，穀倉還沒做，不畫。
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

    let queue: TranscriptionQueue
    let recordingURL: URL
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

    /// 手感參數表：整理好一下成功；失敗一下警告。
    static func feedback(for status: Status) -> SensoryFeedback? {
        switch status {
        case .finished:
            Token.Haptics.transcriptReady
        case .noAPIKey, .transcriptionFailed, .storageFailed, .polishFailed, .draftNotSaved,
             .recordingNotDeleted:
            Token.Haptics.failed
        case .processing:
            nil
        }
    }

    /// 錯誤第二句講原因（06-首次體驗「錯誤」列）；只有金鑰的問題才給「去設定」。
    static func failedStatus(for failure: OpenAIClient.Failure) -> Status {
        switch failure {
        case .timedOut, .transport:
            .transcriptionFailed(reason: "現在沒有網路，連上後會自動整理。", needsNewKey: false)
        case .invalidAPIKey, .missingAPIKey:
            .transcriptionFailed(reason: "金鑰沒有用，到設定換一把。", needsNewKey: true)
        case .quotaExhausted:
            .transcriptionFailed(reason: "OpenAI 說額度用完了，到 OpenAI 後台處理。", needsNewKey: false)
        case .rateLimited, .serverError:
            .transcriptionFailed(reason: "OpenAI 現在忙，等一下再按重試。", needsNewKey: false)
        case .rejected, .malformedResponse, .invalidPath:
            .transcriptionFailed(reason: "OpenAI 沒有收下這段錄音，再試一次。", needsNewKey: false)
        }
    }

    /// 「第 2／3 段」：只有這一筆在轉、而且切成兩段以上才說。
    static func segmentText(
        for activity: TranscriptionQueue.Activity,
        recording: String
    ) -> String? {
        guard case let .transcribing(name, segment, total) = activity else {
            return nil
        }
        guard name == recording, total > 1 else {
            return nil
        }
        return "第 \(segment)／\(total) 段"
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

    /// 面板已經收起（按了「先放著」）就不動剪貼簿：使用者可能正在別處複製東西。
    private func copyIfWanted(_ transcript: Transcript) -> Bool {
        guard isShown, AppSettings.shared.autoCopy else {
            return false
        }
        UIPasteboard.general.string = transcript.displayText
        return true
    }
}

/// 各狀態的內容。按鈕樣式跟錄音前半段一樣：主要動作填滿、其他是文字鈕。
private extension RecordingResultView {
    var processingContent: some View {
        VStack(spacing: Token.Space.m) {
            ProgressView()
            Text("整理中…")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
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
            textButton("先放著") { dismiss() }
        }
    }

    var noAPIKeyContent: some View {
        VStack(spacing: Token.Space.m) {
            message("錄音收好了，在待轉錄。設定金鑰後會自動整理")
            primaryButton("去設定金鑰") { onOpenSettings() }
            textButton("完成") { dismiss() }
        }
    }

    func failedContent(lead: String, reason: String, needsNewKey: Bool) -> some View {
        VStack(spacing: Token.Space.m) {
            failureIcon
            message(lead)
            message(reason)
            primaryButton("重試") { process() }
            if needsNewKey {
                textButton("去設定") { onOpenSettings() }
            }
            textButton("完成") { dismiss() }
        }
    }

    func polishFailedContent(_ transcript: Transcript, message text: String) -> some View {
        VStack(spacing: Token.Space.m) {
            failureIcon
            message(text)
            primaryButton("再試一次") { retryPolish(transcript) }
            textButton("打開這篇") { onOpenTranscript(transcript) }
            textButton("完成") { dismiss() }
        }
    }

    /// 不刪的話下一輪會再整理一次這段錄音，所以叫使用者自己去待轉錄刪。
    func recordingNotDeletedContent(_ transcript: Transcript) -> some View {
        VStack(spacing: Token.Space.m) {
            failureIcon
            message("口語稿已經存好，但錄音檔刪不掉，還在待轉錄。到待轉錄把它刪掉，不然會再整理一次。")
            primaryButton("打開這篇") { onOpenTranscript(transcript) }
            textButton("完成") { dismiss() }
        }
    }

    func finishedContent(_ transcript: Transcript, isCopied: Bool) -> some View {
        VStack(spacing: Token.Space.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(Token.Fonts.largeTitle)
                .foregroundStyle(Token.Colors.link)
                .accessibilityHidden(true)
            message(isCopied ? "好了，已經複製" : "好了")
            primaryButton("打開這篇") { onOpenTranscript(transcript) }
            textButton("完成") { dismiss() }
        }
    }

    var failureIcon: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .font(Token.Fonts.largeTitle)
            .foregroundStyle(Token.Colors.danger)
            .accessibilityHidden(true)
    }

    func message(_ text: String) -> some View {
        Text(text)
            .font(Token.Fonts.body)
            .foregroundStyle(Token.Colors.textPrimary)
            .multilineTextAlignment(.center)
    }

    func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Token.Fonts.rowTitle)
                .frame(maxWidth: .infinity, minHeight: Token.Shape.primaryTap)
        }
        .buttonStyle(.borderedProminent)
        .tint(Token.Colors.link)
    }

    func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(Token.Fonts.body)
            .tint(Token.Colors.link)
    }
}
