@testable import MiSay
import XCTest

/// 片 D4：潤飾請求的形狀與回應。「像不像米講的」只有米讀得出來，這裡不碰。只准在模擬器跑。
final class PolisherTests: XCTestCase {
    private let keyStore = APIKeyStore()
    private let fakeKey = "sk-test-假金鑰-潤飾用"

    override func setUpWithError() throws {
        try keyStore.save(fakeKey)
        FakeOpenAIServer.reset()
    }

    override func tearDownWithError() throws {
        try keyStore.delete()
        FakeOpenAIServer.reset()
    }

    func test潤飾system與user分開送而且user只有這一篇() async throws {
        let reply = #"{"choices":[{"message":{"role":"assistant","content":"  草稿\n"}}]}"#
        FakeOpenAIServer.reply = .http(status: 200, body: reply)
        let draft = try await makePolisher().polish(
            rawText: "呃就是我想說",
            model: Polisher.defaultModel,
            style: .heavy,
            vocabulary: ["DOMYWEB"]
        )
        XCTAssertEqual(draft, "草稿")

        let request = try XCTUnwrap(FakeOpenAIServer.lastRequest)
        XCTAssertEqual(request.url?.path(), Polisher.endpointPath)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-5.4-mini")
        XCTAssertNil(json["temperature"], "GPT-5 系列不收自訂 temperature")
        XCTAssertEqual(Polisher.temperature(for: Polisher.alternativeModel), 0.3)
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertTrue(try XCTUnwrap(messages[0]["content"]).hasPrefix("角色設定："))
        XCTAssertTrue(try XCTUnwrap(messages[0]["content"]).contains("專有名詞（這些字要寫對）：DOMYWEB"))
        XCTAssertEqual(messages[1]["role"], "user")
        XCTAssertEqual(messages[1]["content"], "呃就是我想說")
    }

    func test潤飾大幅潤飾那版有米的草稿規矩() {
        let prompt = PolishStyle.heavy.prompt
        for rule in ["幫忙分段", "只留講得最完整的一次", "不准把兩句合成一句新的話", "只改錯字", "禁止標題", "停在草稿"] {
            XCTAssertTrue(prompt.contains(rule), rule)
        }
        XCTAssertEqual(Polisher.systemContent(prompt: "P", vocabulary: []), "P")
    }

    func test潤飾保留原聲那版有米的刀法而且口語稿包在標籤裡送() async throws {
        let prompt = PolishStyle.keepVoice.prompt
        let rules = ["只留最後一次", "句首接話用的「那」「然後」拿掉", "句首用來解釋的留著", "只輸出整理後的正文"]
        for rule in rules {
            XCTAssertTrue(prompt.contains(rule), rule)
        }
        XCTAssertEqual(PolishStyle.defaultStyle, .keepVoice)

        let reply = #"{"choices":[{"message":{"role":"assistant","content":"草稿"}}]}"#
        FakeOpenAIServer.reply = .http(status: 200, body: reply)
        _ = try await makePolisher().polish(
            rawText: "那我就是想說",
            model: Polisher.defaultModel,
            style: .keepVoice,
            vocabulary: []
        )
        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertTrue(try XCTUnwrap(messages[0]["content"]).hasPrefix("你是逐字稿編輯。"))
        XCTAssertEqual(messages[1]["content"], "<transcript>\n那我就是想說\n</transcript>")
    }

    func test潤飾詳情那行講得出潤飾方式而且舊的篇照舊() {
        XCTAssertEqual(
            TranscriptDetailView.polishNote(model: "m", style: "keepVoice"),
            "潤飾：保留原聲・m"
        )
        XCTAssertEqual(TranscriptDetailView.polishNote(model: "m", style: nil), "潤飾模型：m")
        XCTAssertEqual(TranscriptDetailView.polishNote(model: "m", style: "retired"), "潤飾模型：m")
    }

    func test潤飾暫時錯誤會重試金鑰錯不重試() async throws {
        let reply = #"{"choices":[{"message":{"role":"assistant","content":"好了"}}]}"#
        FakeOpenAIServer.queuedReplies = [
            .http(status: 503, body: ""),
            .http(status: 200, body: reply),
        ]
        let draft = try await makePolisher().polish(
            rawText: "x",
            model: Polisher.defaultModel,
            style: .heavy,
            vocabulary: []
        )
        XCTAssertEqual(draft, "好了")
        XCTAssertEqual(FakeOpenAIServer.requestCount, 2)

        FakeOpenAIServer.reset()
        FakeOpenAIServer.reply = .http(status: 401, body: "")
        do {
            _ = try await polishShort()
            XCTFail("應該要拋錯")
        } catch let failure as OpenAIClient.Failure {
            XCTAssertEqual(failure, .invalidAPIKey(statusCode: 401))
        }
        XCTAssertEqual(FakeOpenAIServer.requestCount, 1)
    }

    func test潤飾回來是空的算失敗() async throws {
        let blank = #"{"choices":[{"message":{"role":"assistant","content":" "}}]}"#
        FakeOpenAIServer.reply = .http(status: 200, body: blank)
        do {
            _ = try await polishShort()
            XCTFail("應該要拋錯")
        } catch let failure as Polisher.Failure {
            XCTAssertEqual(failure, .emptyDraft)
        }
    }

    private func polishShort() async throws -> String {
        try await makePolisher().polish(rawText: "x", model: "m", style: .heavy, vocabulary: [])
    }

    private func makePolisher() -> Polisher {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeOpenAIServer.self]
        let client = OpenAIClient(session: URLSession(configuration: configuration))
        return Polisher(client: client, retryBaseDelaySeconds: 0.01)
    }
}
