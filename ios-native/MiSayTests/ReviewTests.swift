@testable import MiSay
import XCTest

/// Y3 請 AI 看整篇：請求的形狀、回來的 JSON 怎麼驗、引文找位置、失敗講的話。
/// 「意見中不中肯」只有米讀得出來，這裡不碰。送請求的測試只准在模擬器跑（會存假金鑰）。
final class ReviewTests: XCTestCase {
    private let keyStore = APIKeyStore()

    override func setUpWithError() throws {
        try keyStore.save("sk-test-假金鑰-看整篇用")
        FakeOpenAIServer.reset()
    }

    override func tearDownWithError() throws {
        try keyStore.delete()
        FakeOpenAIServer.reset()
    }

    func test看整篇要嚴格JSON_文字稿只在user() async throws {
        FakeOpenAIServer.reply = try reply(content: #"{"titles":["標題一","標題二"]}"#)
        let result = try await review(.titles)
        XCTAssertEqual(result, .titles(["標題一", "標題二"]))

        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, Polisher.defaultModel)
        XCTAssertEqual(json["reasoning_effort"] as? String, "none")

        let format = try XCTUnwrap(json["response_format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        let named = try XCTUnwrap(format["json_schema"] as? [String: Any])
        XCTAssertEqual(named["name"] as? String, "titles")
        XCTAssertEqual(named["strict"] as? Bool, true)

        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        let system = try XCTUnwrap(messages[0]["content"])
        XCTAssertFalse(system.contains("我想講一件事"), "文字稿不准進 system")
        XCTAssertEqual(messages[1]["content"], "<transcript>\n我想講一件事\n</transcript>")
    }

    func test每種形狀的物件都列全欄位而且不准多() throws {
        for kind in ReviewKind.allCases {
            let data = try JSONEncoder().encode(kind.responseFormat.jsonSchema.schema)
            let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            try assertStrict(root)
        }
    }

    func test被截斷或不是說好的形狀都當失敗() async throws {
        FakeOpenAIServer.reply = .http(
            status: 200,
            body: #"{"choices":[{"message":{"role":"assistant","content":"{}"},"#
                + #""finish_reason":"length"}]}"#
        )
        await assertFailure(.incomplete) { _ = try await self.review(.opening) }

        let malformed: [(ReviewKind, String)] = [
            (.titles, "標題一"),
            (.titles, #"{"titles":[]}"#),
            (.titles, #"{"titles":"一個"}"#),
            (.opening, #"{"points":[]}"#),
            (.opening, #"{"summary":" ","points":[]}"#),
            (.stuck, #"{"points":[{"quote":"只有引文"}]}"#),
        ]
        for (kind, content) in malformed {
            XCTAssertThrowsError(try ReviewResult.parse(content, kind: kind), content) { error in
                XCTAssertEqual(error as? Polisher.Failure, .malformedResponse)
            }
        }
    }

    func test標題去重去換行_太長的丟掉_最多五個() throws {
        let long = String(repeating: "長", count: ReviewResult.maxTitleCharacters + 1)
        let titles = [" 一 ", "一", "二\\n三", long, "四", "五", "六", "七"]
        let list = titles.map { "\"\($0)\"" }.joined(separator: ",")
        XCTAssertEqual(
            try ReviewResult.parse("{\"titles\":[\(list)]}", kind: .titles),
            .titles(["一", "二 三", "四", "五", "六"])
        )
    }

    func test開頭夠力時沒有問題清單_卡點最多八條() throws {
        XCTAssertEqual(
            try ReviewResult.parse(#"{"summary":"夠力。","points":[]}"#, kind: .opening),
            .opening(OpeningReview(summary: "夠力。", points: []))
        )
        XCTAssertEqual(
            try ReviewResult.parse(#"{"points":[]}"#, kind: .stuck),
            .stuck([])
        )
        let one = #"{"quote":" 這句 ","reason":"名詞沒解釋"}"#
        let many = Array(repeating: one, count: ReviewKind.maxStuckPoints + 2)
        let content = "{\"points\":[\(many.joined(separator: ","))]}"
        let point = StuckPoint(quote: "這句", reason: "名詞沒解釋")
        XCTAssertEqual(
            try ReviewResult.parse(content, kind: .stuck),
            .stuck(Array(repeating: point, count: ReviewKind.maxStuckPoints))
        )
    }

    func test引文找得到給位置_找不到不給點() {
        XCTAssertEqual(ReviewResult.range(of: "卡住的", in: "前面👨‍👩‍👧卡住的後面"), 3 ..< 6)
        XCTAssertNil(ReviewResult.range(of: "沒有這句", in: "前面後面"))
        XCTAssertNil(ReviewResult.range(of: "", in: "前面後面"))
    }

    func test卡點找得到的照原順序在前_找不到的排最後() {
        let text = "第一句。第二句。第三句。"
        let points = [
            StuckPoint(quote: "已經改掉的", reason: "甲"),
            StuckPoint(quote: "第三句", reason: "乙"),
            StuckPoint(quote: "也找不到", reason: "丙"),
            StuckPoint(quote: "第一句", reason: "丁"),
        ]
        let located = ReviewResult.locate(points, in: text)
        XCTAssertEqual(located.map(\.point.reason), ["乙", "丁", "甲", "丙"])
        XCTAssertEqual(located.map(\.range), [8 ..< 11, 0 ..< 3, nil, nil])
        XCTAssertEqual(ReviewResult.locate([], in: text), [])
    }

    func test同一種只留最近一次_最近問的在前() {
        var session = ReviewSheet.Session()
        session.add(.titles(["舊"]))
        session.add(.stuck([]))
        session.add(.titles(["新"]))
        XCTAssertEqual(session.results, [.titles(["新"]), .stuck([])])
    }

    func test三種提示詞都只給意見_不准補事實_不要AI腔() {
        for kind in ReviewKind.allCases {
            let rules = ["稿子由他自己改", "不准補文字稿沒講的事實", "不要寫成 AI 腔", "不是對你說的", "只輸出 JSON"]
            for rule in rules {
                XCTAssertTrue(kind.prompt.contains(rule), "\(kind.title)：\(rule)")
            }
        }
        XCTAssertTrue(ReviewKind.opening.prompt.contains("不要代寫"))
        XCTAssertTrue(ReviewKind.stuck.prompt.contains("一字不改"))
    }

    func test失敗講的話() {
        let message = TranscriptDetailView.reviewFailureMessage
        XCTAssertEqual(message(OpenAIClient.Failure.timedOut), "現在沒有網路，連上後再按一次。")
        XCTAssertEqual(
            message(OpenAIClient.Failure.missingAPIKey),
            "還沒設定 OpenAI 金鑰，到設定貼上。"
        )
        XCTAssertEqual(message(Polisher.Failure.incomplete), "意見回到一半被截掉了，再按一次試試。")
        XCTAssertEqual(
            message(Polisher.Failure.malformedResponse),
            "OpenAI 回來的意見看不懂，再按一次試試。"
        )
    }

    private func review(_ kind: ReviewKind) async throws -> ReviewResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeOpenAIServer.self]
        let client = OpenAIClient(session: URLSession(configuration: configuration))
        return try await Polisher(client: client, retryBaseDelaySeconds: 0.01).review(
            text: "我想講一件事",
            kind: kind,
            model: Polisher.defaultModel,
            vocabulary: []
        )
    }

    private func reply(content: String) throws -> FakeOpenAIServer.Reply {
        let message = ["role": "assistant", "content": content]
        let body = try JSONSerialization.data(
            withJSONObject: ["choices": [["message": message, "finish_reason": "stop"]]]
        )
        return try .http(status: 200, body: XCTUnwrap(String(bytes: body, encoding: .utf8)))
    }

    private func assertFailure(
        _ expected: Polisher.Failure,
        _ work: () async throws -> Void
    ) async {
        do {
            try await work()
            XCTFail("應該要拋錯")
        } catch {
            XCTAssertEqual(error as? Polisher.Failure, expected)
        }
    }

    /// strict 規定：每一層物件都要 `additionalProperties: false`、欄位全列在 `required`。
    private func assertStrict(_ schema: [String: Any]) throws {
        if let items = schema["items"] as? [String: Any] {
            try assertStrict(items)
        }
        guard let properties = schema["properties"] as? [String: [String: Any]] else {
            return
        }
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
        XCTAssertEqual(schema["required"] as? [String], properties.keys.sorted())
        for property in properties.values {
            try assertStrict(property)
        }
    }
}
