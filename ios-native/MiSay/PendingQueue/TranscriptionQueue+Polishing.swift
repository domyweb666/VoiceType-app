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
        let finished = mergeIntoAppendTarget(polished)
        TranscriptReadyNotice().post(for: finished)
        return .finished(finished)
    }

    /// K3：這篇是「接著錄」錄的，整理好就接到原本那篇後面，自己這篇刪掉。
    /// 原本那篇讀不到（剛好被刪了）、存不進去、正在整理、或正開在詳情頁：照舊留成獨立的一篇，字不會丟。
    /// 後兩種接上去，對方存回來時會拿舊的那份蓋掉接上去的字。
    /// 2026-11-09：打字時在游標處接著錄的，插在記下的位置；那附近被改掉找不到，就接在最後面、記下來讓詳情頁講一聲。
    private func mergeIntoAppendTarget(_ added: Transcript) -> Transcript {
        guard let appendTarget = appendTargetsByTranscript.removeValue(forKey: added.id),
              !inFlight.contains(appendTarget.transcriptID.uuidString),
              !openForEditing.contains(appendTarget.transcriptID),
              var target = (try? store.loadAll())?.transcripts
              .first(where: { $0.id == appendTarget.transcriptID })
        else {
            return added
        }
        let movedToEnd: Bool
        if let insertion = appendTarget.insertion {
            movedToEnd = !target.insert(added, at: insertion)
        } else {
            target.append(added)
            movedToEnd = false
        }
        do {
            try store.save(target)
        } catch {
            return added
        }
        if movedToEnd {
            insertionsMovedToEnd.insert(target.id)
        }
        // 刪不掉只會多一篇重複的，不會少字；下次使用者自己刪。
        try? store.delete(id: added.id)
        DiagnosticLog.shared.record(
            appendTarget.insertion == nil || movedToEnd ? "接著錄：接到原本那篇後面" : "接著錄：插在游標處"
        )
        return target
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
