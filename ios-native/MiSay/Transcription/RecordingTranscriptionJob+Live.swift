import Foundation

/// 邊錄邊轉（S4-1）：錄音中把刀位已經定下來的段先轉。正在寫的錄音檔只讀不寫；
/// 字記在錄音停止後會搬去的那個位置的進度檔（`progressAt`），停止後整理流水照常讀它、只補剩下的段。
extension RecordingTranscriptionJob {
    /// 送出去失敗不拋：記一筆就回來，下一輪再試，停止後整理流水也會補。錄音不受影響。
    func transcribeFinishedSegments(ofLive liveURL: URL, progressAt finalURL: URL) async {
        guard let segments = try? WAVSegmenter.finishedSegments(ofLive: liveURL),
              !segments.isEmpty
        else {
            return
        }
        var progress = loadProgress(for: finalURL)
        progress.adopt(segments)
        let baseName = finalURL.deletingPathExtension().lastPathComponent
        for (index, segment) in segments.enumerated() where progress.segmentTexts[index] == nil {
            let previousText = (0 ..< index).compactMap { progress.segmentTexts[$0] }.joined()
            do {
                let request = try SegmentRequest(
                    audio: WAVSegmenter.read(segment, from: liveURL),
                    filename: String(format: "%@-%02d.wav", baseName, index + 1),
                    prompt: TranscriptionPrompt.build(
                        vocabulary: vocabulary,
                        previousText: previousText
                    ),
                    label: "錄音中先轉第 \(index + 1) 段"
                )
                let text = try await send(request)
                if Self.looksShort(text, audio: request.audio) {
                    // 錄音中不重送：停止後整理流水看到這段沒字，會照 S2-2 的規矩重送、標漏字。
                    return
                }
                progress.segmentTexts[index] = text
                try saveProgress(progress, for: finalURL)
            } catch {
                return
            }
        }
    }
}
