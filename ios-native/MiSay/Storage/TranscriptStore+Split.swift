import Foundation

/// 片 J3 拆篇的存檔：一件事一篇，編號用那件事的。
extension TranscriptStore {
    /// 回沒存成的那幾件。原篇照存檔裡的看：不在了、進了垃圾桶的一篇都不存，丟 `notFound`。
    /// 一篇沒存成不擋其他篇。時間一篇差一秒：清單新的在上面，第一件事才會排最上面。
    func saveSplit(
        _ topics: [SplitTopic],
        of sourceID: UUID,
        now: Date = Date()
    ) throws -> Set<UUID> {
        guard let source = try load(id: sourceID), source.trashedAt == nil else {
            throw Failure.notFound
        }
        var failedIDs: Set<UUID> = []
        for (index, topic) in topics.enumerated() {
            let date = now.addingTimeInterval(-Double(index))
            do {
                try savePiece(topic, of: source, at: date)
            } catch {
                failedIDs.insert(topic.id)
            }
        }
        return failedIDs
    }

    /// 存檔裡已經有這一篇：不再存，免得蓋掉改過的字。
    private func savePiece(_ topic: SplitTopic, of source: Transcript, at date: Date) throws {
        guard try load(id: topic.id) == nil else {
            return
        }
        let piece = Transcript.split(
            from: source,
            id: topic.id,
            title: topic.title,
            text: topic.text,
            now: date
        )
        try save(piece)
    }
}
