@testable import MiSay
import XCTest

/// W4 改一段：切出選的那段與前後文、換上時找得回原本那段、請求的形狀、提示詞的規矩。
/// 送請求的測試只准在模擬器跑（會存假金鑰）。
final class PassageRewriteTests: XCTestCase {
    private let keyStore = APIKeyStore()

    override func setUpWithError() throws {
        try keyStore.save("sk-test-假金鑰-改一段用")
        FakeOpenAIServer.reset()
    }

    override func tearDownWithError() throws {
        try keyStore.delete()
        FakeOpenAIServer.reset()
    }

    func test切出選的那段和前後文_超出範圍回nil() throws {
        let passage = try XCTUnwrap(PassageContext(in: "前面。中間這段。後面。", offset: 3, length: 5))
        XCTAssertEqual(passage, PassageContext(text: "中間這段。", before: "前面。", after: "後面。"))

        XCTAssertNil(PassageContext(in: "短", offset: 0, length: 2))
        XCTAssertNil(PassageContext(in: "短", offset: 0, length: 0))
        XCTAssertNil(PassageContext(in: "短", offset: -1, length: 1))
    }

    func test前後文只帶一小段() throws {
        let long = String(repeating: "前", count: 1000) + "這段" + String(repeating: "後", count: 1000)
        let passage = try XCTUnwrap(PassageContext(in: long, offset: 1000, length: 2))
        XCTAssertEqual(passage.text, "這段")
        XCTAssertEqual(passage.before.count, PassageRewriteKind.contextCharacters)
        XCTAssertEqual(passage.after.count, PassageRewriteKind.contextCharacters)
    }

    func test換上_位置對得上換那裡_被移動過找得到_找不到不換() {
        XCTAssertEqual(
            PassageContext.replacing("舊的", at: 2, with: "新的", in: "開頭舊的結尾"),
            "開頭新的結尾"
        )
        // 等的時候前面多打了字，位置往後移了：照原本那段找。
        XCTAssertEqual(
            PassageContext.replacing("舊的", at: 2, with: "新的", in: "我加了開頭舊的結尾"),
            "我加了開頭新的結尾"
        )
        XCTAssertNil(PassageContext.replacing("舊的", at: 2, with: "新的", in: "整段都改掉了"))
    }

    func test改一段只送那段和前後文_都在user() async throws {
        let reply = #"{"choices":[{"message":{"role":"assistant","content":"短一點的。\n"}}]}"#
        FakeOpenAIServer.reply = .http(status: 200, body: reply)
        let passage = PassageContext(text: "很長很長的這段", before: "前文", after: "後文")
        let result = try await makePolisher().rewritePassage(
            passage,
            kind: .shorten,
            model: Polisher.defaultModel,
            vocabulary: []
        )
        XCTAssertEqual(result, "短一點的。")

        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        let system = try XCTUnwrap(messages[0]["content"])
        XCTAssertTrue(system.contains("縮短到大約一半"))
        XCTAssertFalse(system.contains("很長很長的這段"), "選的字不准進 system")
        XCTAssertEqual(
            messages[1]["content"],
            "<before>\n前文\n</before>\n<passage>\n很長很長的這段\n</passage>\n<after>\n後文\n</after>"
        )
    }

    func test四種提示詞都只輸出那一段_講清楚不准加新事實() {
        for kind in PassageRewriteKind.allCases {
            let prompt = kind.prompt
            for rule in ["只輸出改好的那一段", "不准補文字稿沒講的事實", "不要寫成 AI 腔"] {
                XCTAssertTrue(prompt.contains(rule), "\(kind.title)：\(rule)")
            }
        }
        XCTAssertTrue(PassageRewriteKind.expand.prompt.contains("不准加新的事實"))
    }

    private func makePolisher() -> Polisher {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeOpenAIServer.self]
        let client = OpenAIClient(session: URLSession(configuration: configuration))
        return Polisher(client: client, retryBaseDelaySeconds: 0.01)
    }
}
