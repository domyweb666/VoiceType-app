import SwiftUI

/// 完成面板的純判斷：觸覺、失敗原因翻成人話、第幾段。有測試；2026-11-07 從面板檔搬出來。
extension RecordingResultView {
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
        guard case let .transcribing(name, segment, total) = activity, name == recording,
              total > 1
        else {
            return nil
        }
        return "第 \(segment)／\(total) 段"
    }
}
