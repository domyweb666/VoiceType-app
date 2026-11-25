import Foundation

/// 片 J2「可能改了意思」（2026-11-25 米：防改原意）：口語稿有、AI 整理完變少的否定字、數字、詞彙表的名字。
/// 只在手機上比，不送任何地方、不存檔、不改稿。只列出來給人確認，不判斷對錯。
struct MeaningCheck: Equatable, Sendable {
    enum Kind: String, Sendable {
        case negation = "否定字"
        case number = "數字"
        case name = "名字"
    }

    struct Finding: Equatable, Identifiable, Sendable {
        let kind: Kind
        /// 在口語稿的第幾個字，估錄音位置用。
        let offset: Int
        let before: String
        let word: String
        let after: String

        var id: String {
            "\(kind.rawValue)-\(offset)"
        }
    }

    /// 那個字前後各帶幾個字給人看。
    static let excerptLength = 14

    let findings: [Finding]

    init(raw: String, polished: String, vocabulary: [String]) {
        guard !raw.isEmpty, !polished.isEmpty else {
            findings = []
            return
        }
        let comparison = MeaningComparison(raw: raw, polished: polished)
        let spoken = comparison.originals
        let negations = comparison.lostNegations().map { (kind: Kind.negation, range: $0) }
        let numbers = comparison.lostNumbers().map { (kind: Kind.number, range: $0) }
        let names = comparison.lostNames(vocabulary).map { (kind: Kind.name, range: $0) }
        findings = (negations + numbers + names)
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
            .map { Self.finding($0.kind, at: $0.range, in: spoken) }
    }

    private static func finding(
        _ kind: Kind,
        at range: Range<Int>,
        in spoken: [Character]
    ) -> Finding {
        let start = max(0, range.lowerBound - excerptLength)
        let end = min(spoken.count, range.upperBound + excerptLength)
        let before = oneLine(spoken[start ..< range.lowerBound])
        let after = oneLine(spoken[range.upperBound ..< end])
        return Finding(
            kind: kind,
            offset: range.lowerBound,
            before: start > 0 ? "…" + before : before,
            word: oneLine(spoken[range]),
            after: end < spoken.count ? after + "…" : after
        )
    }

    private static func oneLine(_ characters: ArraySlice<Character>) -> String {
        String(characters.map { $0.isNewline ? " " : $0 })
    }
}
