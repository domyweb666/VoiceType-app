import Foundation

/// 方塊 M4：口語稿 → 草稿；W1 起也把文字稿改寫成別的格式。system 與 user 分開送（安全標準五）、只送這一篇、回來的當純文字。
/// 只對可重試的錯誤重試，最多 3 次（PRD）。模型與潤飾方式由 M7 決定；提示詞全文在 `PolishStyle`。
struct Polisher {
    enum Failure: Error, Equatable {
        case malformedResponse
        case emptyDraft
        /// 回來了但沒有正常結束（`finish_reason` 是 length 之類）：半篇不存，當失敗（S2-2）。
        case incomplete
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

    /// 自訂詞彙（F2）與學到的習慣（11/08）接在 system 提示詞後面，口語稿永遠只在 user 那一則。
    func polish(
        rawText: String,
        model: String,
        style: PolishStyle,
        vocabulary: [String],
        habits: [String] = []
    ) async throws -> String {
        let system = Self.systemContent(
            prompt: style.prompt,
            vocabulary: vocabulary,
            habits: habits
        )
        return try await complete(
            system: system,
            user: style.userContent(rawText: rawText),
            model: model
        )
    }

    /// W1 改寫成別的格式：從文字稿出發，整篇一次送（長度上限在 `RewriteKind`）。
    /// 學到的改稿習慣是給潤飾用的，不帶；詞彙照帶，人名品牌才不會在改寫時又寫錯。
    func rewrite(
        text: String,
        kind: RewriteKind,
        model: String,
        vocabulary: [String]
    ) async throws -> String {
        try await complete(
            system: Self.systemContent(prompt: kind.prompt, vocabulary: vocabulary),
            user: RewriteKind.userContent(text: text),
            model: model
        )
    }

    /// 潤飾與改寫共用：送一次 chat completions，可重試的錯誤重試，回來的當純文字。
    private func complete(system: String, user: String, model: String) async throws -> String {
        let request = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: user),
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
        return try Self.draft(from: data)
    }

    /// 回應先驗形狀再拿字。沒帶 finish_reason 的回應照舊收；有帶而且不是 stop，
    /// 就是被截斷或被擋，半篇不能當文字稿（S2-2）。
    private static func draft(from data: Data) throws -> String {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(ChatResponse.self, from: data) else {
            throw Failure.malformedResponse
        }
        if let reason = response.choices.first?.finishReason, reason != "stop" {
            throw Failure.incomplete
        }
        let draft = (response.choices.first?.message.content ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else {
            throw Failure.emptyDraft
        }
        return draft
    }

    static func systemContent(
        prompt: String,
        vocabulary: [String],
        habits: [String] = []
    ) -> String {
        let words = vocabulary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var content = prompt
        if !words.isEmpty {
            content += "\n\n專有名詞（這些字要寫對）：" + words.joined(separator: "、")
        }
        // 從這個人的修改學來的；跟上面衝突時照這裡，因為這是他自己改出來的樣子。
        if !habits.isEmpty {
            content += "\n\n這個人的改稿習慣（跟上面規則衝突時，照這裡）：\n"
                + habits.map { "- " + $0 }.joined(separator: "\n")
        }
        return content
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
        /// JSON 裡是 finish_reason；解碼時用 convertFromSnakeCase 對上。
        let finishReason: String?
    }
}
