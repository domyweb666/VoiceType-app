import Foundation

/// 「請 AI 看整篇」回來的意見。模型回的 JSON 先驗形狀再用（安全標準五），缺欄位、型別不對都當失敗。
enum ReviewResult: Equatable, Identifiable {
    case titles([String])
    case opening(OpeningReview)
    case stuck([StuckPoint])

    /// 再長就不像標題了，超過的丟掉。
    static let maxTitleCharacters = 60

    var kind: ReviewKind {
        switch self {
        case .titles: .titles
        case .opening: .opening
        case .stuck: .stuck
        }
    }

    var id: ReviewKind {
        kind
    }

    static func parse(_ content: String, kind: ReviewKind) throws -> ReviewResult {
        switch kind {
        case .titles:
            try .titles(cleanedTitles(from: content))
        case .opening:
            try .opening(cleanedOpening(from: content))
        case .stuck:
            try .stuck(cleanedPoints(from: content))
        }
    }

    /// 那句引文在現在的稿子裡是第幾個字到第幾個字；改掉了、或模型沒照抄，就是 nil，不給點。
    static func range(of quote: String, in text: String) -> Range<Int>? {
        guard !quote.isEmpty, let found = text.range(of: quote, options: .literal) else {
            return nil
        }
        let start = text.distance(from: text.startIndex, to: found.lowerBound)
        return start ..< start + text.distance(from: found.lowerBound, to: found.upperBound)
    }

    /// 「請 AI 看整篇」R-C 的翻頁順序：找得到位置的照 AI 排的順序在前，找不到的排最後。
    /// 找不到的不標在稿子上、不給跳（設計稿 R-C5「翻到最後會看到」），編號跟著這個順序。
    static func locate(_ points: [StuckPoint], in text: String) -> [LocatedStuckPoint] {
        let located = points.map {
            LocatedStuckPoint(point: $0, range: range(of: $0.quote, in: text))
        }
        return located.filter { $0.range != nil } + located.filter { $0.range == nil }
    }

    private static func cleanedTitles(from content: String) throws -> [String] {
        let payload = try decode(TitlesPayload.self, from: content)
        var seen = Set<String>()
        var titles: [String] = []
        for candidate in payload.titles {
            let lines = candidate.split(whereSeparator: \.isNewline)
            let title = trimmed(lines.joined(separator: " "))
            let fits = !title.isEmpty && title.count <= maxTitleCharacters
            if fits, seen.insert(title).inserted {
                titles.append(title)
            }
        }
        guard !titles.isEmpty else {
            throw Polisher.Failure.malformedResponse
        }
        return Array(titles.prefix(ReviewKind.maxTitles))
    }

    private static func cleanedOpening(from content: String) throws -> OpeningReview {
        let payload = try decode(OpeningReview.self, from: content)
        let summary = trimmed(payload.summary)
        guard !summary.isEmpty else {
            throw Polisher.Failure.malformedResponse
        }
        let points = payload.points
            .map { OpeningPoint(problem: trimmed($0.problem), direction: trimmed($0.direction)) }
            .filter { !$0.problem.isEmpty && !$0.direction.isEmpty }
            .prefix(ReviewKind.maxOpeningPoints)
        return OpeningReview(summary: summary, points: Array(points))
    }

    private static func cleanedPoints(from content: String) throws -> [StuckPoint] {
        let payload = try decode(StuckPayload.self, from: content)
        let points = payload.points
            .map { StuckPoint(quote: trimmed($0.quote), reason: trimmed($0.reason)) }
            .filter { !$0.quote.isEmpty && !$0.reason.isEmpty }
            .prefix(ReviewKind.maxStuckPoints)
        return Array(points)
    }

    private static func decode<Payload: Decodable>(
        _ type: Payload.Type,
        from content: String
    ) throws -> Payload {
        do {
            return try JSONDecoder().decode(type, from: Data(content.utf8))
        } catch {
            throw Polisher.Failure.malformedResponse
        }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 開頭的意見：一兩句結論，加上哪裡沒力、往哪改。夠力時 `points` 是空的。
struct OpeningReview: Decodable, Equatable {
    let summary: String
    let points: [OpeningPoint]
}

struct OpeningPoint: Decodable, Equatable {
    let problem: String
    let direction: String
}

/// 讀者會卡住的一處：原文一句，加上為什麼。
struct StuckPoint: Decodable, Equatable {
    let quote: String
    let reason: String
}

/// 一處卡點加上它在現在的稿子裡是第幾個字到第幾個字；改掉了、或模型沒照抄，就是 nil。
struct LocatedStuckPoint: Equatable {
    let point: StuckPoint
    let range: Range<Int>?
}

private struct TitlesPayload: Decodable {
    let titles: [String]
}

private struct StuckPayload: Decodable {
    let points: [StuckPoint]
}
