import Foundation

/// 自動續轉（片 D5、S2-4）：首頁出現、回到前景時叫。先把待轉錄的錄音一筆一筆做完，
/// 再補潤飾沒做完的篇（停止後鎖屏、斷網、App 被殺都可能停在潤飾中間）。
extension TranscriptionQueue {
    /// 只補這麼近的篇：更早的沒有文字稿，多半是潤飾一直失敗、使用者自己決定放著，
    /// 每次回到前景都重送會一直花錢。詳情頁有「整理這篇」可以手動補。
    static let resumePolishWithinSeconds: TimeInterval = 24 * 60 * 60

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
        await resumeUnfinishedPolishing()
    }

    /// 從最舊的開始補；哪一篇失敗就停（跟錄音同一條規矩），下次回到前景再來。
    private func resumeUnfinishedPolishing() async {
        guard let loaded = try? store.loadAll() else {
            return
        }
        let cutoff = Date().addingTimeInterval(-Self.resumePolishWithinSeconds)
        for transcript in loaded.transcripts.reversed()
            where Self.needsPolishResume(transcript, since: cutoff)
        {
            // 面板或詳情頁正在潤飾這篇：不重送，同一篇不同時花兩次錢。
            guard !inFlight.contains(transcript.id.uuidString) else {
                continue
            }
            guard case .finished = await retryPolish(transcript) else {
                return
            }
        }
    }

    /// 還沒有文字稿、口語稿不是空的、而且是做到一半的（有做好的塊）或是最近一天的。
    static func needsPolishResume(_ transcript: Transcript, since cutoff: Date) -> Bool {
        guard transcript.draftText == nil,
              !transcript.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }
        return transcript.polishedChunks != nil || transcript.createdAt >= cutoff
    }
}
