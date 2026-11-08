import Foundation

/// 從錄音重新轉錄（S2-5）：留存區還有這篇的錄音時，用它重轉一次，換掉口語稿，再重新潤飾。
/// 存回同一篇（id 不變），錄音留著不動；進度檔放在留存錄音旁邊，轉完就清。
extension TranscriptionQueue {
    func retranscribe(_ transcript: Transcript) async -> Outcome? {
        let name = transcript.id.uuidString
        guard !inFlight.contains(name) else {
            return nil
        }
        guard let url = try? retained.url(for: transcript.id),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return .recordingUnreadable
        }
        inFlight.insert(name)
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
