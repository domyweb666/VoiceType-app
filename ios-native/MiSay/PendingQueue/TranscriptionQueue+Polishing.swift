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
        // 手上那份可能是舊的：別處整理好了、接過錄音，就不用再送。
        // 存檔一時讀不到就不送：拿舊的去潤飾會白花錢，也可能蓋掉新的。
        let current: Transcript
        do {
            current = try latest(of: transcript)
        } catch {
            DiagnosticLog.shared.record("潤飾先不送，存檔一時讀不到：\(type(of: error))")
            return .polishFailed(transcript, .malformedResponse)
        }
        guard current.draftText == nil else {
            return .finished(current)
        }
        activity = .polishing(recording: name)
        inFlight.insert(name)
        defer {
            resetActivity(ifShowing: name)
            finishInFlight(name)
        }
        return await polishAndSave(current)
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
                try saveKeepingUserFields(&working)
            } catch {
                return .draftNotSaved(transcript)
            }
        }
        var polished = working
        polished.applyPolish(PolishChunks.join(drafts), model: model, style: style)
        do {
            try saveKeepingUserFields(&polished)
        } catch {
            return .draftNotSaved(working)
        }
        let finished = mergeIntoAppendTarget(polished)
        postReadyNotice(for: finished)
        return .finished(finished)
    }

    /// 存檔裡最新的那份；已經不在清單、存檔壞了就用手上的。一時讀不到丟錯：手上的可能是舊的。
    func latest(of transcript: Transcript) throws -> Transcript {
        let stored = try ignoringBroken { try store.load(id: transcript.id) }
        return stored ?? transcript
    }

    /// 潤飾要好幾分鐘，這段時間人可能改了標題、標籤（還沒有文字稿的篇也能取標題）；流水手上的是開始時那份，
    /// 存之前把人改的換成存檔裡最新的，不然會蓋回去。存檔壞了就照手上的存（壞的會先另存）；
    /// 一時讀不到就丟錯不存，口語稿還在，之後再整理一次。
    /// 這段時間被丟進垃圾桶的，存在垃圾桶那份，不放回清單。
    func saveKeepingUserFields(_ transcript: inout Transcript) throws {
        let id = transcript.id
        if let stored = try ignoringBroken({ try store.load(id: id) }) {
            transcript.keepUserFields(from: stored)
        } else if let trashed = try ignoringBroken({ try store.loadFromTrash(id: id) }) {
            transcript.keepUserFields(from: trashed)
            try store.saveInTrash(transcript)
            return
        }
        try store.save(transcript)
    }

    private func ignoringBroken(_ read: () throws -> Transcript?) throws -> Transcript? {
        do {
            return try read()
        } catch TranscriptStore.Failure.unreadable {
            return nil
        }
    }

    /// 還在等著接回去的那段，通知點下去要打開的是原本那篇：獨立那一篇等一下就併掉了。
    private func postReadyNotice(for finished: Transcript) {
        // 整理到一半被丟進垃圾桶：點通知也打不開，不發。
        guard finished.trashedAt == nil else {
            return
        }
        guard let waiting = waitingAppends.first(where: { $0.addedID == finished.id }) else {
            TranscriptReadyNotice().post(for: finished)
            return
        }
        let stored = (try? store.loadAll())?.transcripts ?? []
        let target = stored.first { $0.id == waiting.target.transcriptID }
        TranscriptReadyNotice().post(for: target ?? finished)
    }

    func polishChunk(
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
                vocabulary: settings.vocabulary
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
