@testable import MiSay
import XCTest

/// 2026-11-08 自動詞彙、從修改學習：找改過的地方、模型回應怎麼清、詞彙怎麼加怎麼刪、習慣怎麼接進提示詞。
/// 送出去那一段用假伺服器，不碰真的 OpenAI。
final class LearnFromEditsTests: XCTestCase {
    private let suiteName = "LearnFromEditsTests"
    private let keyStore = APIKeyStore()

    override func setUpWithError() throws {
        try keyStore.save("sk-test-假金鑰-學習用")
        FakeOpenAIServer.reset()
    }

    override func tearDownWithError() throws {
        try keyStore.delete()
        FakeOpenAIServer.reset()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    // MARK: - 找改過的地方

    func test換字會抓到改前改後和前後文() throws {
        let hunks = EditDiff.hunks(from: "下午去全連買東西。", to: "下午去全聯買東西。")

        let hunk = try XCTUnwrap(hunks.first)
        XCTAssertEqual(hunks.count, 1)
        XCTAssertEqual(hunk.before, "連")
        XCTAssertEqual(hunk.after, "聯")
        XCTAssertEqual(hunk.leading, "下午去全")
        XCTAssertEqual(hunk.trailing, "買東西。")
    }

    func test只改標點空白不算修改() {
        XCTAssertEqual(EditDiff.hunks(from: "好，我知道了", to: "好。我知道了！"), [])
    }

    func test兩處分開的修改算兩處() {
        let hunks = EditDiff.hunks(from: "我想說那個米說很好用然後就這樣", to: "我想說米說很好用，就這樣")
        XCTAssertEqual(hunks.count, 2)
    }

    func test沒學過的修改從原稿算起_學過就從學過那份算() {
        var transcript = Transcript(durationSeconds: 1, rawText: "x")
        transcript.applyPolish("原稿", model: "m", style: .keepVoice)
        XCTAssertNil(transcript.unlearnedEdit)

        transcript.draftText = "改過"
        XCTAssertEqual(transcript.unlearnedEdit?.from, "原稿")

        transcript.learnedDraft = "改過"
        XCTAssertNil(transcript.unlearnedEdit)
    }

    // MARK: - 模型回應

    func test回應的詞與習慣會清乾淨() throws {
        let payload = #"{"vocabulary":["全聯"," 全聯 ","聯",""],"habits":["數字寫阿拉伯數字","數字寫阿拉伯數字"]}"#
        let data = try chatReply(content: payload)
        let result = try EditLearner.parse(data)

        XCTAssertEqual(result.vocabulary, ["全聯"])
        XCTAssertEqual(result.habits, ["數字寫阿拉伯數字"])
    }

    func test回應不是JSON就算失敗() throws {
        XCTAssertThrowsError(try EditLearner.parse(chatReply(content: "好的")))
    }

    func test只開自動詞彙時不送現有習慣而且習慣原樣留著() async throws {
        let payload = #"{"vocabulary":["全聯"],"habits":["亂學的"]}"#
        FakeOpenAIServer.reply = try .http(
            status: 200,
            body: String(decoding: chatReply(content: payload), as: UTF8.self)
        )
        let result = try await makeLearner().learn(
            from: [EditHunk(before: "連", after: "聯", leading: "去全", trailing: "買")],
            currentHabits: ["秘密習慣"],
            wantsHabits: false,
            model: Polisher.defaultModel
        )

        XCTAssertEqual(result.vocabulary, ["全聯"])
        XCTAssertEqual(result.habits, ["秘密習慣"])
        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertFalse(text.contains("秘密習慣"))
        XCTAssertTrue(text.contains("json_object"))
    }

    // MARK: - 詞彙與習慣

    func test自動詞彙不重複_刪過的不再加回來() throws {
        let settings = try makeSettings()
        settings.vocabulary = ["DOMYWEB"]

        XCTAssertEqual(settings.addAutoVocabulary(["domyweb", "全聯", "全聯"]), ["全聯"])
        XCTAssertTrue(settings.isAutoAdded("全聯"))
        XCTAssertFalse(settings.isAutoAdded("DOMYWEB"))

        settings.removeVocabulary(atOffsets: IndexSet(integer: 1))
        XCTAssertEqual(settings.vocabulary, ["DOMYWEB"])
        XCTAssertEqual(settings.addAutoVocabulary(["全聯"]), [])
    }

    func test自動詞彙滿了先刪最舊的自動詞_手動的不動() throws {
        let settings = try makeSettings()
        settings.vocabulary = ["手動"]
        let words = (1 ... AppSettings.maxAutoVocabulary + 1).map { "詞\($0)" }
        settings.addAutoVocabulary(words)

        XCTAssertTrue(settings.vocabulary.contains("手動"))
        XCTAssertFalse(settings.vocabulary.contains("詞1"))
        XCTAssertEqual(settings.vocabulary.count, AppSettings.maxAutoVocabulary + 1)
    }

    func test預設自動詞彙開_學習關_關著時習慣不進提示詞() throws {
        let settings = try makeSettings()
        XCTAssertTrue(settings.autoVocabulary)
        XCTAssertFalse(settings.learnFromEdits)

        settings.learnedHabits = ["句尾的啦要留"]
        XCTAssertEqual(settings.activeHabits, [])
        settings.learnFromEdits = true
        XCTAssertEqual(settings.activeHabits, ["句尾的啦要留"])
    }

    func test習慣接在潤飾提示詞後面() {
        let content = Polisher.systemContent(prompt: "P", vocabulary: [], habits: ["句尾的啦要留"])
        XCTAssertTrue(content.hasPrefix("P"))
        XCTAssertTrue(content.contains("- 句尾的啦要留"))
        XCTAssertEqual(Polisher.systemContent(prompt: "P", vocabulary: [], habits: []), "P")
    }

    // MARK: - 工具

    private func makeSettings() throws -> AppSettings {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    private func makeLearner() -> EditLearner {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeOpenAIServer.self]
        let client = OpenAIClient(session: URLSession(configuration: configuration))
        return EditLearner(client: client, retryBaseDelaySeconds: 0.01)
    }

    /// 包成 chat completions 的回應形狀。
    private func chatReply(content: String) throws -> Data {
        let reply: [String: Any] = ["choices": [["message": [
            "role": "assistant",
            "content": content,
        ]]]]
        return try JSONSerialization.data(withJSONObject: reply)
    }
}
