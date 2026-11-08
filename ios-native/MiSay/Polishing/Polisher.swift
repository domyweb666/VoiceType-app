import Foundation

/// 方塊 M4：口語稿 → 草稿。system 與 user 分開送（安全標準五）、只送這一篇、回來的當純文字。
/// 只對可重試的錯誤重試，最多 3 次（PRD）。模型與潤飾方式由 M7 決定；提示詞全文在 `PolishStyle`。
struct Polisher {
    enum Failure: Error, Equatable {
        case malformedResponse
        case emptyDraft
    }

    /// 2026-11-01 查證：gpt-5.4-mini 存在（輸入 0.75／輸出 4.50 美元每百萬 token）；
    /// gpt-4o-mini 存在但已標 Deprecated（輸入 0.15／輸出 0.60）。預設跟網頁版一樣。
    static let defaultModel = "gpt-5.4-mini"
    static let alternativeModel = "gpt-4o-mini"
    static let maxAttempts = 3
    static let retryBaseDelaySeconds: Double = 2
    /// 只有 gpt-4 系列帶：GPT-5 系列不收自訂 temperature（會回 400），網頁版 docs/index.html 也是這樣分。
    static let gpt4Temperature = 0.3
    static let endpointPath = "/v1/chat/completions"

    private let client: OpenAIClient
    private let retryBaseDelaySeconds: Double

    init(
        client: OpenAIClient = OpenAIClient(),
        retryBaseDelaySeconds: Double = Polisher.retryBaseDelaySeconds
    ) {
        self.client = client
        self.retryBaseDelaySeconds = retryBaseDelaySeconds
    }

    /// 自訂詞彙（F2）接在 system 提示詞後面，口語稿永遠只在 user 那一則。
    func polish(
        rawText: String,
        model: String,
        style: PolishStyle,
        vocabulary: [String]
    ) async throws -> String {
        let system = Self.systemContent(prompt: style.prompt, vocabulary: vocabulary)
        let request = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: style.userContent(rawText: rawText)),
            ],
            temperature: Self.temperature(for: model)
        )
        let body: Data
        do {
            body = try JSONEncoder().encode(request)
        } catch {
            throw Failure.malformedResponse
        }
        let data = try await OpenAIClient.retrying(
            maxAttempts: Self.maxAttempts,
            baseDelaySeconds: retryBaseDelaySeconds
        ) {
            try await client.send(
                path: Self.endpointPath,
                method: "POST",
                body: body,
                contentType: "application/json",
                timeoutSeconds: OpenAIClient.requestTimeoutSeconds
            )
        }
        guard let response = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw Failure.malformedResponse
        }
        let draft = (response.choices.first?.message.content ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else {
            throw Failure.emptyDraft
        }
        return draft
    }

    static func systemContent(prompt: String, vocabulary: [String]) -> String {
        let words = vocabulary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !words.isEmpty else {
            return prompt
        }
        return prompt + "\n\n專有名詞（這些字要寫對）：" + words.joined(separator: "、")
    }

    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    static func temperature(for model: String) -> Double? {
        model.hasPrefix("gpt-4") ? gpt4Temperature : nil
    }

    /// temperature 是 nil 時整個欄位不送（Encodable 合成的會略過 nil）。
    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double?
    }

    private struct ChatResponse: Decodable {
        let choices: [ChatChoice]
    }

    private struct ChatChoice: Decodable {
        let message: ChatMessage
    }
}
