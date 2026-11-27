import SwiftUI

/// 錄音面板的後半段（片 D6）：停止之後的整理中、完成、失敗、沒金鑰、潤飾失敗。文案照 06-首次體驗「錄音面板」。
/// 整理跑在不跟畫面綁的 Task 裡：按「收起來」收起面板，流水照樣在背景跑完；錄音檔在口語稿存好前都在待轉錄。
/// 2026-11-07 統一風格：完成面板多三行文字稿預覽；純判斷搬到 `RecordingResultView+Status.swift`。
struct RecordingResultView: View {
    enum Status: Equatable {
        case processing
        case noAPIKey
        case transcriptionFailed(reason: String, needsNewKey: Bool)
        case storageFailed
        case progressUnreadable
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
    /// Y4：在編輯頁上錄的，字要回到這一篇。有值就不給「打開這篇」「去設定」：人就在那一頁，不換頁。
    var returningTo: UUID?
    /// 首頁原地版（2026-11-26）收起來時叫它；nil 是半頁面板，用系統的 dismiss。
    var onClose: (() -> Void)?

    @Environment(\.dismiss) var dismiss
    @State private var status = Status.processing
    @State private var hasStarted = false
    @State private var isShown = true
    /// 第一次整理才出現的費用說明；開始時記下來，不然一設成看過就馬上消失。
    @State var showsCostNotice = !AppSettings.shared.hasSeenCostNotice
    /// 整理中進度條要畫幾格（這段錄音切成幾段）。
    @State var segmentTotal = 1

    var body: some View {
        RecordingTrayLayout {
            stage
        } tray: {
            tray
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedbackIfEnabled(trigger: status) { _, new in
            Self.feedback(for: new)
        }
        .onAppear {
            guard !hasStarted else {
                return
            }
            hasStarted = true
            process()
        }
        // 原地版切到別的分頁再回來會再出現一次：看得到就照常複製、照常收。
        .onAppear { isShown = true }
        .onDisappear { isShown = false }
        // 進到潤飾時 activity 就不再帶段數，先記住切成幾段，進度條才不會從三格變一格。
        .onChange(of: queue.activity, initial: true) { _, activity in
            let name = recordingURL.lastPathComponent
            if let total = Self.segmentCount(for: activity, recording: name) {
                segmentTotal = total
            }
        }
    }

    /// 收起來：原地版回到待機，半頁面板收下去。
    func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    func process() {
        status = .processing
        Task { @MainActor in
            let outcome = await queue.process(recordingAt: recordingURL)
            apply(outcome)
        }
    }

    func retryPolish(_ transcript: Transcript) {
        status = .processing
        Task { @MainActor in
            let outcome = await queue.retryPolish(transcript)
            apply(outcome)
        }
    }

    private func apply(_ outcome: TranscriptionQueue.Outcome?) {
        // 費用說明要等真的送出去過才算看過：沒金鑰時面板一閃就換掉，不能算。
        if let outcome, outcome != .noAPIKey, outcome != .progressUnreadable {
            AppSettings.shared.hasSeenCostNotice = true
        }
        switch outcome {
        case nil:
            // 背景那一輪已經在整理這一筆，交給它；面板收起，好了會出現在文字稿。
            close()
        case .noAPIKey:
            status = .noAPIKey
        case let .transcriptionFailed(failure):
            status = Self.failedStatus(for: failure)
        case .storageFailed, .progressUnreadable:
            status = outcome == .progressUnreadable ? .progressUnreadable : .storageFailed
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
            dismissIfReturned(transcript)
        }
    }

    /// 字已經回到底下那一頁，面板自己收；中間斷過的要留著給人看。
    private func dismissIfReturned(_ transcript: Transcript) {
        if transcript.id == returningTo, captureGaps.times == 0, isShown {
            close()
        }
    }

    /// 面板已經收起（按了「收起來」）就不動剪貼簿：使用者可能正在別處複製東西。
    /// 在編輯頁上錄的也不動：人還在寫，整篇還沒要拿走。
    private func copyIfWanted(_ transcript: Transcript) -> Bool {
        guard isShown, returningTo == nil, AppSettings.shared.autoCopy else {
            return false
        }
        DraftPasteboard.copy(transcript.displayText)
        return true
    }
}

/// 各狀態的內容，照 B 版拆成上半部（給人看）和托盤（給人按）。
/// 主要動作金棕膠囊、其他文字鈕深金（使用規則第 2、11 條）。失敗的原因用狀態條講（使用規則第 13 條）。
extension RecordingResultView {
    @ViewBuilder
    var stage: some View {
        switch status {
        case .processing:
            processingStage
        case .noAPIKey:
            noAPIKeyStage
        case let .transcriptionFailed(reason, _):
            failedStage(lead: "錄音還在待轉錄，沒有被扣款。", reason: reason)
        case .storageFailed:
            // 這時已經轉好、已經扣款，所以不說「沒有被扣款」。
            failedStage(lead: "錄音還在待轉錄。", reason: "口語稿存不進去，再試一次。")
        case .progressUnreadable:
            failedStage(lead: "轉錄進度一時讀不到，錄音還在。", reason: "等一下再按重試。")
        case .polishFailed:
            failedStage(lead: nil, reason: "口語稿已經存好，潤飾沒有成功。")
        case .draftNotSaved:
            failedStage(lead: nil, reason: "口語稿已經存好，文字稿存不進去。再試一次會重新潤飾。")
        case .recordingNotDeleted:
            failedStage(
                lead: nil,
                reason: "口語稿已經存好，但錄音檔刪不掉，還在待轉錄。到待轉錄把它刪掉，不然會再整理一次。"
            )
        case let .finished(transcript, isCopied):
            finishedStage(transcript, isCopied: isCopied)
        }
    }

    @ViewBuilder
    var tray: some View {
        switch status {
        case .processing:
            Button("收起來") { close() }
                .buttonStyle(TextButtonStyle())
        case .noAPIKey:
            noAPIKeyTray
        case let .transcriptionFailed(_, needsNewKey):
            retryTray(needsNewKey: needsNewKey)
        case .storageFailed, .progressUnreadable:
            retryTray(needsNewKey: false)
        case let .polishFailed(transcript), let .draftNotSaved(transcript):
            polishFailedTray(transcript)
        case let .recordingNotDeleted(transcript):
            recordingNotDeletedTray(transcript)
        case let .finished(transcript, _):
            finishedTray(transcript)
        }
    }

    /// 大標：首頁原地版照 B 版用大標；半頁面板只有半個螢幕高，小一級。
    var titleFont: Font {
        onClose == nil ? Token.Fonts.sectionTitle : Token.Fonts.largeTitle
    }

    /// 錄音中途斷過的那一行（B4），每個結局都放在大標下面。
    @ViewBuilder
    var gapLine: some View {
        if let gapText = RecordingSheetView.gapText(for: captureGaps) {
            Text(gapText)
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
        }
    }

    func message(_ text: String) -> some View {
        Text(text)
            .font(Token.Fonts.secondary)
            .foregroundStyle(Token.Colors.textPrimary)
    }
}
