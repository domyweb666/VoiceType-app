import Foundation

/// 潤飾這一步（片 D4、D6、S2-3）：口語稿已在歷史，切成塊一塊一塊送，每塊好了就存進這一篇；
/// 失敗再來只送還沒好的塊。全部好了才接成文字稿。
extension TranscriptionQueue {
    /// 片 D6「重試潤飾」：口語稿已在歷史，只重送潤飾，成功就存回同一篇。
    /// 這篇已經在潤飾（自動續做、面板、詳情頁其中一邊）就回 nil，不同時花兩次錢。
    func retryPolish(_ transcript: Transcript) async -> Outcome? {
        let name = transcript.id.uuidString
        guard !inFlight.contains(name) else {
            return nil
        }
        activity = .polishing(recording: name)
        inFlight.insert(name)
        defer {
            inFlight.remove(name)
            resetActivity(ifShowing: name)
        }
        return await polishAndSave(transcript)
    }

    /// 失敗時帶回去的那一篇已經存了做好的塊，下次拿它重試就從下一塊接著做。
    func polishAndSave(_ transcript: Transcript) async -> Outcome {
        let model = settings.polishModel
        let style = settings.polishStyle
        let chunks = PolishChunks.split(transcript.rawText)
        var working = transcript
        var drafts = working.polishedChunks ?? []
        // 口語稿被改過、塊數對不上：做好的塊不能用，從頭來。
        if drafts.count > chunks.count {
            drafts = []
        }
        for index in drafts.count ..< chunks.count {
            let label = "潤飾 \(model) \(style.rawValue) 第 \(index + 1)/\(chunks.count) 塊"
            switch await polishChunk(chunks[index], model: model, style: style, label: label) {
            case let .success(draft):
                drafts.append(draft)
            case let .failure(failure):
                return .polishFailed(working, failure)
            }
            guard index < chunks.count - 1 else {
                break
            }
            working.polishedChunks = drafts
            do {
                try store.save(working)
            } catch {
                return .draftNotSaved(transcript)
            }
        }
        var polished = working
        polished.applyPolish(PolishChunks.join(drafts), model: model, style: style)
        do {
            try store.save(polished)
        } catch {
            return .draftNotSaved(working)
        }
        return .finished(polished)
    }

    private func polishChunk(
        _ chunk: String,
        model: String,
        style: PolishStyle,
        label: String
    ) async -> Result<String, OpenAIClient.Failure> {
        let startedAt = Date()
        do {
            let draft = try await polisher.polish(
                rawText: chunk,
                model: model,
                style: style,
                vocabulary: settings.vocabulary,
                habits: settings.activeHabits
            )
            let waited = Int(Date().timeIntervalSince(startedAt))
            DiagnosticLog.shared.record(
                "\(label)，等了 \(waited) 秒，\(chunk.count) 字變 \(draft.count) 字"
            )
            return .success(draft)
        } catch let failure as OpenAIClient.Failure {
            logPolishFailure(failure, label: label, startedAt: startedAt)
            return .failure(failure)
        } catch {
            logPolishFailure(error, label: label, startedAt: startedAt)
            return .failure(.malformedResponse)
        }
    }

    private func logPolishFailure(_ error: Error, label: String, startedAt: Date) {
        let waited = Int(Date().timeIntervalSince(startedAt))
        DiagnosticLog.shared.record("\(label)失敗，等了 \(waited) 秒：\(error)")
    }
}
