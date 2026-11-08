import Foundation

/// 自動續轉（片 D5、S2-4）：首頁出現、回到前景時叫。先把待轉錄的錄音一筆一筆做完，
/// 再補潤飾沒做完的篇（停止後鎖屏、斷網、App 被殺都可能停在潤飾中間）。
extension TranscriptionQueue {
    /// 只補這麼近的篇：更早的沒有文字稿，多半是潤飾一直失敗、使用者自己決定放著，
    /// 每次回到前景都重送會一直花錢。詳情頁有「整理這篇」可以手動補。
    static let resumePolishWithinSeconds: TimeInterval = 24 * 60 * 60
    /// 在背景待超過這麼久，系統多半已經把 App 暫停過：手上的請求可能卡著等到 180 秒超時才放棄，
    /// 回到前景時直接取消重送（S2-7）。做好的段與塊都存了，重送只送手上那一段。
    static let stuckAfterBackgroundSeconds: TimeInterval = 30

    /// 首頁出現時叫。不用畫面自己的 .task：推頁時首頁會消失、.task 被取消，整理到一半的那筆會被當成失敗。
    func startPendingRun() {
        launchPendingRun(after: nil)
    }

    func noteBackgrounded() {
        lastBackgroundedAt = Date()
    }

    func returnedToForeground() {
        defer { lastBackgroundedAt = nil }
        guard isProcessingPending,
              let backgroundedAt = lastBackgroundedAt,
              Date().timeIntervalSince(backgroundedAt) >= Self.stuckAfterBackgroundSeconds
        else {
            launchPendingRun(after: nil)
            return
        }
        DiagnosticLog.shared.record("回到前景，取消卡住的整理重送")
        let stuck = pendingRun
        stuck?.cancel()
        launchPendingRun(after: stuck)
    }

    /// 上一輪被取消時先等它收完，新的一輪才開始；不然兩輪交錯，「失敗就停」就不準了。
    private func launchPendingRun(after previous: Task<Void, Never>?) {
        // 正在跑的那一輪要留著它的 Task：之後回到前景要取消的是它，不是一個馬上就結束的新 Task。
        if previous == nil, isProcessingPending {
            return
        }
        pendingRun = Task { [weak self] in
            await previous?.value
            await self?.processPending()
        }
    }

    /// 自動續轉：從最舊的開始，一筆一筆；哪一筆失敗就停，等下次條件齊了再來。
    func processPending() async {
        // 首頁出現、回到前景都會叫；同一時間只跑一輪，不然兩輪會交錯、「失敗就停」就不準了。
        guard !isProcessingPending, let recordings = try? pending.list() else {
            return
        }
        isProcessingPending = true
        defer { isProcessingPending = false }
        if let loaded = try? store.loadAll() {
            retained.purge(loaded: loaded, excluding: inFlight)
        }
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

    /// S2-8 待轉錄單筆「整理這一個」：被標紅的也再試一次（換了金鑰之後用得到），還是被拒就再標回去。
    func processOne(recordingAt url: URL) async -> Outcome? {
        let name = url.lastPathComponent
        refusedRecordings.remove(name)
        let outcome = await process(recordingAt: url)
        switch outcome {
        case .transcriptionFailed(.rejected), .recordingUnreadable:
            refusedRecordings.insert(name)
        default:
            break
        }
        return outcome
    }

    /// 從最舊的開始補；哪一篇失敗就停（跟錄音同一條規矩），下次回到前景再來。
    private func resumeUnfinishedPolishing() async {
        guard let loaded = try? store.loadAll() else {
            return
        }
        let cutoff = Date().addingTimeInterval(-Self.resumePolishWithinSeconds)
        let candidates = loaded.transcripts.reversed().filter {
            Self.needsPolishResume($0, since: cutoff)
        }
        for transcript in candidates {
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
