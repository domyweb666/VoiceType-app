import SwiftUI

/// 完成面板的純判斷：觸覺、失敗原因翻成人話、第幾段、整理中進度條的格子。有測試；2026-11-07 從面板檔搬出來。
extension RecordingResultView {
    /// 手感參數表：整理好一下成功；失敗一下警告。
    static func feedback(for status: Status) -> SensoryFeedback? {
        switch status {
        case .finished:
            Token.Haptics.transcriptReady
        case .noAPIKey, .transcriptionFailed, .storageFailed, .progressUnreadable, .polishFailed,
             .draftNotSaved, .recordingNotDeleted:
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
        case .missingAPIKey:
            .transcriptionFailed(reason: "還沒設定 OpenAI 金鑰，到設定貼上。", needsNewKey: true)
        case .invalidAPIKey:
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

    /// 整理中進度條的一格（B3）：轉好了、正在轉、還沒輪到。
    enum ProgressCell: Equatable {
        case done
        case working
        case waiting
    }

    /// 這段錄音切成幾段：只有正在轉它的時候知道；不是它就回 nil，畫面沿用上次記下的。
    static func segmentCount(
        for activity: TranscriptionQueue.Activity,
        recording: String
    ) -> Int? {
        guard case let .transcribing(name, _, total) = activity, name == recording else {
            return nil
        }
        return max(total, 1)
    }

    /// 「轉成文字」那排格子：一段一格。轉到第幾段，前面的算轉好、這一格算正在轉。
    /// 已經在潤飾就全部轉好；還沒開始（或流水在忙別筆）就全部還沒輪到。
    static func transcriptionCells(
        for activity: TranscriptionQueue.Activity,
        recording: String,
        knownTotal: Int
    ) -> [ProgressCell] {
        switch activity {
        case let .transcribing(name, segment, total) where name == recording:
            return (1 ... max(total, 1)).map { index -> ProgressCell in
                if index < segment {
                    return .done
                }
                return index == segment ? .working : .waiting
            }
        case let .polishing(name) where name == recording:
            return Array(repeating: .done, count: max(knownTotal, 1))
        default:
            return Array(repeating: .waiting, count: max(knownTotal, 1))
        }
    }

    /// 流水正在潤飾這一筆（B3 下面那行「潤飾」）。
    static func isPolishing(_ activity: TranscriptionQueue.Activity, recording: String) -> Bool {
        guard case let .polishing(name) = activity else {
            return false
        }
        return name == recording
    }
}
