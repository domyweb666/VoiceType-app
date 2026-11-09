import Foundation

/// 從錄音重新轉錄（S2-5）：留存區還有這篇的錄音時，用它重轉一次，換掉口語稿，再重新潤飾。
/// 存回同一篇（id 不變），錄音留著不動；進度檔放在留存錄音旁邊，轉完就清。
extension TranscriptionQueue {
    /// K4：一直留著的是 m4a，先解回 WAV 才切得了段；解一小時要好幾秒，放背景。
    private func recordingForRetranscription(of id: UUID) async -> URL? {
        let retained = retained
        return await Task.detached(priority: .userInitiated) {
            try? retained.wavForRetranscription(of: id)
        }.value
    }

    func retranscribe(_ transcript: Transcript) async -> Outcome? {
        let name = transcript.id.uuidString
        guard !inFlight.contains(name) else {
            return nil
        }
        // 解碼之前就算在用：背景壓縮不會同時動這個檔（K 審查）。
        inFlight.insert(name)
        guard let url = await recordingForRetranscription(of: transcript.id) else {
            inFlight.remove(name)
            return .recordingUnreadable
        }
        defer {
            inFlight.remove(name)
            // 轉錄那一步的進度用錄音檔名記，潤飾那一步用 id 記，兩個都要歸零。
            resetActivity(ifShowing: url.lastPathComponent)
            resetActivity(ifShowing: name)
        }
        let job = RecordingTranscriptionJob(
            transcriber: transcriber,
            vocabulary: settings.vocabulary
        )
        let rawText: String
        switch await transcribe(url, with: job) {
        case let .success(text):
            rawText = text
        case let .failure(stopped):
            return stopped.value
        }
        var updated = transcript
        updated.replaceRawText(
            rawText,
            possiblyMissing: job.possiblyMissingSegments(forRecordingAt: url)
        )
        do {
            try store.save(updated)
        } catch {
            return .storageFailed
        }
        job.cleanUp(recordingAt: url)
        activity = .polishing(recording: name)
        return await polishAndSave(updated)
    }
}
