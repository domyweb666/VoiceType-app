import Foundation

/// 潤飾這一步（片 D4、D6）：口語稿已在歷史，送潤飾、成功就存回同一篇。
extension TranscriptionQueue {
    /// 片 D6「重試潤飾」：口語稿已在歷史，只重送潤飾，成功就存回同一篇。
    func retryPolish(_ transcript: Transcript) async -> Outcome {
        let name = transcript.id.uuidString
        activity = .polishing(recording: name)
        defer { resetActivity(ifShowing: name) }
        return await polishAndSave(transcript)
    }

    func polishAndSave(_ transcript: Transcript) async -> Outcome {
        var polished = transcript
        let model = settings.polishModel
        let style = settings.polishStyle
        let startedAt = Date()
        do {
            let draft = try await polisher.polish(
                rawText: transcript.rawText,
                model: model,
                style: style,
                vocabulary: settings.vocabulary,
                habits: settings.activeHabits
            )
            polished.applyPolish(draft, model: model, style: style)
            let waited = Int(Date().timeIntervalSince(startedAt))
            DiagnosticLog.shared.record(
                "潤飾 \(model) \(style.rawValue)，等了 \(waited) 秒，"
                    + "\(transcript.rawText.count) 字變 \(draft.count) 字"
            )
        } catch let failure as OpenAIClient.Failure {
            logPolishFailure(failure, model: model, startedAt: startedAt)
            return .polishFailed(transcript, failure)
        } catch {
            logPolishFailure(error, model: model, startedAt: startedAt)
            return .polishFailed(transcript, .malformedResponse)
        }
        do {
            try store.save(polished)
        } catch {
            return .draftNotSaved(transcript)
        }
        return .finished(polished)
    }

    private func logPolishFailure(_ error: Error, model: String, startedAt: Date) {
        let waited = Int(Date().timeIntervalSince(startedAt))
        DiagnosticLog.shared.record("潤飾 \(model) 失敗，等了 \(waited) 秒：\(error)")
    }
}
