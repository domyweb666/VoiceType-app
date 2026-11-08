import Foundation

/// 自動續轉（片 D5）：首頁出現、回到前景時叫。
extension TranscriptionQueue {
    /// 自動續轉：從最舊的開始，一筆一筆；哪一筆失敗就停，等下次條件齊了再來。
    func processPending() async {
        // 首頁出現、回到前景都會叫；同一時間只跑一輪，不然兩輪會交錯、「失敗就停」就不準了。
        guard !isProcessingPending, let recordings = try? pending.list() else {
            return
        }
        isProcessingPending = true
        defer { isProcessingPending = false }
        for recording in recordings.reversed() {
            // 清單是開跑時拍的照：這段時間面板可能已經整理完那一筆、錄音檔已刪。
            let exists = FileManager.default.fileExists(atPath: recording.url.path)
            guard exists, !refusedRecordings.contains(recording.id) else {
                continue
            }
            let outcome = await process(recordingAt: recording.url)
            switch outcome {
            case .finished, .polishFailed, .draftNotSaved, nil:
                continue
            case .transcriptionFailed(.rejected), .recordingUnreadable:
                refusedRecordings.insert(recording.id)
            case .noAPIKey, .transcriptionFailed, .storageFailed, .recordingNotDeleted:
                return
            }
        }
    }
}
