import Foundation

/// 2026-11-24 Y5：改寫好的不再是掛在原篇底下的一份唯讀文字，存成自己的一篇，能改、能匯出、有版本。
/// 沒有錄音也沒有口語稿；`sourceID` 記原篇，原篇刪了它照樣在。
extension Transcript {
    private static let headingMark = "# "
    private static let boldMark = "**"

    /// 從別篇改寫來的。
    var isDerived: Bool {
        sourceID != nil
    }

    /// 改寫的結果存成新的一篇。三份文字稿一樣：還沒被人改過，版本紀錄留得住 AI 給的那份。
    /// 結果開頭就是「# 標題」的拿去當標題，正文不再重複；沒有就沿用原篇的標題。
    static func derived(
        from source: Transcript,
        rewrite: TranscriptRewrite,
        now: Date = Date()
    ) -> Transcript {
        let (heading, body) = splitHeading(of: rewrite.text)
        var derived = Transcript(
            id: rewrite.id,
            createdAt: rewrite.createdAt,
            durationSeconds: 0,
            rawText: "",
            draftText: body,
            polishModel: rewrite.model,
            originalDraft: body,
            learnedDraft: body,
            updatedAt: now
        )
        derived.title = heading ?? source.title
        derived.tags = source.tags
        derived.sourceID = source.id
        derived.sourceKind = rewrite.kind
        derived.sourceInstruction = rewrite.instruction
        return derived
    }

    /// 從這篇改寫來的那些，新的在前；垃圾桶裡的不算。
    static func derived(of sourceID: UUID, in transcripts: [Transcript]) -> [Transcript] {
        transcripts
            .filter { $0.sourceID == sourceID && $0.trashedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 第一個非空行是「# 標題」才拆；只有標題沒有內文的不拆，不然正文是空的。
    static func splitHeading(of text: String) -> (heading: String?, body: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
        guard let first = lines.first, first.hasPrefix(headingMark) else {
            return (nil, trimmed)
        }
        let rest = lines.dropFirst().joined(separator: "\n")
        let body = rest.trimmingCharacters(in: .newlines)
        let mark = first.dropFirst(headingMark.count)
        let heading = withoutBoldMarks(mark.trimmingCharacters(in: .whitespaces))
        guard !heading.isEmpty, !body.isEmpty else {
            return (nil, trimmed)
        }
        return (heading, body)
    }

    /// AI 有時把標題寫成「# **標題**」；標題不吃 Markdown，整行包著的粗體記號拿掉。
    private static func withoutBoldMarks(_ heading: String) -> String {
        let isBold = heading.hasPrefix(boldMark) && heading.hasSuffix(boldMark)
        guard isBold, heading.count > boldMark.count * 2 else {
            return heading
        }
        return String(heading.dropFirst(boldMark.count).dropLast(boldMark.count))
    }
}
