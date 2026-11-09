@testable import MiSay
import XCTest

/// W1 改寫成其他格式：請求的形狀、提示詞的規矩、存在這篇底下不動文字稿、失敗講的話。
/// 「改得像不像米寫的」只有米讀得出來，這裡不碰。送請求的測試只准在模擬器跑（會存假金鑰）。
final class RewriteTests: XCTestCase {
    private let keyStore = APIKeyStore()

    override func setUpWithError() throws {
        try keyStore.save("sk-test-假金鑰-改寫用")
        FakeOpenAIServer.reset()
    }

    override func tearDownWithError() throws {
        try keyStore.delete()
        FakeOpenAIServer.reset()
    }

    func test改寫system帶格式要求和詞彙_文字稿包標籤只在user() async throws {
        let reply = #"{"choices":[{"message":{"role":"assistant","content":"  # 標題\n內文\n"}}]}"#
        FakeOpenAIServer.reply = .http(status: 200, body: reply)
        let text = try await makePolisher().rewrite(
            text: "我想講一件事",
            kind: .newsletter,
            model: Polisher.defaultModel,
            vocabulary: ["DOMYWEB"]
        )
        XCTAssertEqual(text, "# 標題\n內文")

        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        let system = try XCTUnwrap(messages[0]["content"])
        XCTAssertTrue(system.contains("改寫成一封電子報"))
        XCTAssertTrue(system.contains("專有名詞（這些字要寫對）：DOMYWEB"))
        XCTAssertFalse(system.contains("我想講一件事"), "文字稿不准進 system")
        XCTAssertEqual(messages[1]["content"], "<transcript>\n我想講一件事\n</transcript>")
    }

    func test改寫被截斷當失敗不存半篇() async throws {
        let reply = #"{"choices":[{"message":{"role":"assistant","content":"半篇"},"#
            + #""finish_reason":"length"}]}"#
        FakeOpenAIServer.reply = .http(status: 200, body: reply)
        do {
            _ = try await makePolisher().rewrite(
                text: "x",
                kind: .article,
                model: "m",
                vocabulary: []
            )
            XCTFail("finish_reason 是 length 應該失敗")
        } catch let failure as Polisher.Failure {
            XCTAssertEqual(failure, .incomplete)
        }
    }

    func test五種提示詞都有不准補內容和不要AI腔() {
        for kind in RewriteKind.allCases {
            let prompt = kind.prompt
            for rule in ["不准補文字稿沒講的事實", "台灣用語", "不要寫成 AI 腔", "不是對你說的", "只輸出改寫好的內容"] {
                XCTAssertTrue(prompt.contains(rule), "\(kind.title)：\(rule)")
            }
        }
        XCTAssertTrue(RewriteKind.outline.prompt.contains("一字不改"))
        XCTAssertEqual(RewriteKind.title(forStored: "threads"), "Threads 串文")
        XCTAssertEqual(RewriteKind.title(forStored: "以後拿掉的"), "以後拿掉的")
    }

    func test改寫存在這篇底下_文字稿不動_刪光回到nil() {
        var transcript = Transcript(durationSeconds: 10, rawText: "口語")
        transcript.applyPolish("文字稿。", model: "m", style: .keepVoice)
        let rewrite = TranscriptRewrite(kind: RewriteKind.article.rawValue, text: "文章", model: "m")

        transcript.addRewrite(rewrite)
        XCTAssertEqual(transcript.rewrites, [rewrite])
        XCTAssertEqual(transcript.draftText, "文字稿。")
        XCTAssertEqual(transcript.originalDraft, "文字稿。")
        XCTAssertNil(transcript.unlearnedEdit, "改寫不算使用者改字")

        transcript.removeRewrite(id: rewrite.id)
        XCTAssertNil(transcript.rewrites)
    }

    func test舊檔沒有改寫欄也讀得出來() throws {
        let json = """
        {"id":"\(UUID().uuidString)","createdAt":"2026-11-01T00:00:00Z","durationSeconds":3,
        "rawText":"舊的","updatedAt":"2026-11-01T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertNil(try decoder.decode(Transcript.self, from: Data(json.utf8)).rewrites)
    }

    func test選單標題與失敗講的話() {
        XCTAssertEqual(TranscriptDetailView.rewriteMenuTitle(copies: 0), "改寫成其他格式…")
        XCTAssertEqual(TranscriptDetailView.rewriteMenuTitle(copies: 2), "改寫成其他格式（2 份）")
        let message = TranscriptDetailView.rewriteFailureMessage
        XCTAssertEqual(message(OpenAIClient.Failure.missingAPIKey), "金鑰沒有用，到設定換一把。")
        XCTAssertEqual(message(OpenAIClient.Failure.timedOut), "現在沒有網路，連上後再按一次。")
        XCTAssertEqual(message(Polisher.Failure.incomplete), "改寫到一半被截掉了，沒有存。")
        XCTAssertEqual(
            message(TranscriptDetailView.RewriteFailure.transcriptGone),
            "這篇已經刪掉了，改寫的沒有存。"
        )
    }

    func test補充要求接在system最後_不准補內容那條蓋不掉_文字稿照舊只在user() async throws {
        let reply = #"{"choices":[{"message":{"role":"assistant","content":"文章"}}]}"#
        FakeOpenAIServer.reply = .http(status: 200, body: reply)
        _ = try await makePolisher().rewrite(
            text: "我想講一件事",
            kind: .article,
            model: Polisher.defaultModel,
            vocabulary: [],
            instruction: "保留我舉的例子"
        )
        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        let system = try XCTUnwrap(messages[0]["content"])
        XCTAssertTrue(system.hasSuffix("：\n保留我舉的例子"))
        XCTAssertTrue(system.contains("只有「不准補文字稿沒講的事實」那條不能被蓋掉"))
        XCTAssertEqual(messages[1]["content"], "<transcript>\n我想講一件事\n</transcript>")

        XCTAssertEqual(RewriteKind.appending(nil, to: "P"), "P", "沒打就跟 W1 一模一樣")
    }

    func test補充要求去空白_空的和太長的不送() {
        XCTAssertEqual(RewriteKind.cleanedInstruction("  用大白話 \n"), "用大白話")
        XCTAssertNil(RewriteKind.cleanedInstruction("   "))
        let long = String(repeating: "字", count: RewriteKind.maxInstructionCharacters + 1)
        XCTAssertNil(RewriteKind.cleanedInstruction(long))
        XCTAssertEqual(RewritesSheet.instructionNote(characters: 10), "只用在這次改寫，你的潤飾方式不會變。")
        XCTAssertEqual(RewritesSheet.instructionNote(characters: 201), "補充要求最多 200 字，現在 201 字。")
    }

    func test改寫記得當時的補充要求_W2以前的讀得出來() throws {
        let rewrite = TranscriptRewrite(kind: "article", text: "文章", model: "m", instruction: "大白話")
        let data = try JSONEncoder().encode(rewrite)
        XCTAssertEqual(
            try JSONDecoder().decode(TranscriptRewrite.self, from: data).instruction,
            "大白話"
        )

        let old = #"{"id":"\#(UUID().uuidString)","kind":"article","#
            + #""text":"文章","model":"m","createdAt":0}"#
        let decoded = try JSONDecoder().decode(TranscriptRewrite.self, from: Data(old.utf8))
        XCTAssertNil(decoded.instruction)
    }

    private func makePolisher() -> Polisher {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeOpenAIServer.self]
        let client = OpenAIClient(session: URLSession(configuration: configuration))
        return Polisher(client: client, retryBaseDelaySeconds: 0.01)
    }
}
