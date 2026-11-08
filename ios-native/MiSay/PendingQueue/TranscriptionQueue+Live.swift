import Foundation

/// 邊錄邊轉（S4-1，米 11/08 放行做法 D）：錄音中每隔一陣子看一次，有段錄完了就先送去轉錄。
/// 按停止時只剩最後一段和潤飾，一分鐘內做完；手機收進口袋也一樣，因為錄音中 App 本來就醒著。
extension TranscriptionQueue {
    static let liveCheckIntervalSeconds = 15

    /// 錄音面板開始錄之後叫。`liveURL` 是正在寫的錄音檔；停止後它會用同一個檔名搬進待轉錄。
    func startLive(recordingAt liveURL: URL) {
        // 上一段沒收乾淨（例如面板不是按停止關掉的）：先停掉，不讓兩輪同時讀。
        liveRun?.cancel()
        liveRun = nil
        guard let pendingDirectory = try? pending.directoryURL() else {
            return
        }
        let finalURL = pendingDirectory.appending(path: liveURL.lastPathComponent)
        let job = RecordingTranscriptionJob(
            transcriber: transcriber,
            vocabulary: settings.vocabulary
        )
        DiagnosticLog.shared.record("邊錄邊轉開始")
        liveRun = Task { [weak self] in
            // 錄音檔搬走或不見了（停止、被撿回）就收工。
            while !Task.isCancelled, FileManager.default.fileExists(atPath: liveURL.path) {
                try? await Task.sleep(for: .seconds(Self.liveCheckIntervalSeconds))
                guard !Task.isCancelled, self?.canTranscribeWhileRecording() == true else {
                    continue
                }
                await job.transcribeFinishedSegments(ofLive: liveURL, progressAt: finalURL)
            }
        }
    }

    /// 按停止、錄音檔搬進待轉錄之前叫。手上那段直接取消，不讓使用者等它；停止後整理流水會補送那一段。
    func finishLive() async {
        guard let run = liveRun else {
            return
        }
        liveRun = nil
        run.cancel()
        await run.value
        DiagnosticLog.shared.record("邊錄邊轉停下")
    }

    /// 沒金鑰就不送（一直失敗沒意義）；設了只用 Wi-Fi 而現在走行動網路，也先不送，停止後再整理。
    func canTranscribeWhileRecording() -> Bool {
        if settings.liveTranscriptionWiFiOnly, NetworkPath.shared.isExpensive {
            return false
        }
        return (try? APIKeyStore().read()) != nil
    }
}
