import Foundation

/// 邊錄邊轉（S4-1）：錄音中把刀位已經定下來的段先轉。正在寫的錄音檔只讀不寫；
/// 字記在錄音停止後會搬去的那個位置的進度檔（`progressAt`），停止後整理流水照常讀它、只補剩下的段。
extension RecordingTranscriptionJob {
    /// 送出去失敗不拋：記一筆就回來，下一輪再試，停止後整理流水也會補。錄音不受影響。
    /// 字數太少、或 OpenAI 拒收（再送也一樣）的段記進 `liveSkippedSegments`，錄音中不再送，免得每 15 秒重送一次。
    func transcribeFinishedSegments(ofLive liveURL: URL, progressAt finalURL: URL) async {
        var progress = loadProgress(for: finalURL)
        guard Self.mayHaveNewWork(progress, liveURL: liveURL),
              let segments = try? WAVSegmenter.finishedSegments(ofLive: liveURL),
              !segments.isEmpty
        else {
            return
        }
        progress.adopt(segments)
        let baseName = finalURL.deletingPathExtension().lastPathComponent
        let todo = segments.indices.filter {
            progress.segmentTexts[$0] == nil && !progress.liveSkippedSegments.contains($0)
        }
        for index in todo {
            let segment = segments[index]
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
                    progress.liveSkippedSegments.insert(index)
                } else {
                    progress.segmentTexts[index] = text
                }
                try saveProgress(progress, for: finalURL)
            } catch let failure as OpenAIClient.Failure where !failure.isRetryable {
                progress.liveSkippedSegments.insert(index)
                try? saveProgress(progress, for: finalURL)
                return
            } catch {
                return
            }
        }
    }

    /// 上次切到的段都處理過了，而且錄到的還不夠下一刀（下一刀要等那一分鐘錄完）：這一輪不用重讀整個檔。
    /// 一小時的檔每 15 秒重讀一次很耗電。
    static func mayHaveNewWork(_ progress: Progress, liveURL: URL) -> Bool {
        let known = progress.segments ?? []
        let handled = known.indices.allSatisfy {
            progress.segmentTexts[$0] != nil || progress.liveSkippedSegments.contains($0)
        }
        guard handled else {
            return true
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: liveURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        let bytesPerFrame = WAVFileWriter.channelCount * WAVFileWriter.bitsPerSample / 8
        let recordedFrames = max(0, fileSize - WAVFileWriter.headerByteCount) / bytesPerFrame
        let lastEnd = known.last?.endFrame ?? 0
        return recordedFrames - lastEnd > WAVSegmenter.latestCutSeconds * WAVFileWriter.sampleRate
    }
}
