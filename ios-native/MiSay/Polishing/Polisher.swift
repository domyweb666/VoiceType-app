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

    /// 2026-11-07 米定案，2026-11-24 上 OpenAI 官方文件查證：在、能走 chat completions。
    /// gpt-4o-mini 2027-01-14 關閉、gpt-5.4-mini 沒地方選，都拿掉了。
    static let defaultModel = "gpt-6-luna"
    /// gpt-6-luna 預設 medium，第一個字來得很慢，要明講。官方模型頁寫收 none。
    /// temperature 不帶：reasoning 不是 none 時帶了會被拒，用預設值最穩。
    static let reasoningEffort = "none"
    static let maxAttempts = 3
    static let retryBaseDelaySeconds: Double = 2
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
        return try await complete(
            system: system,
            user: style.userContent(rawText: rawText),
            model: model
        )
    }

    /// W1 改寫成別的格式：從文字稿出發，整篇一次送（長度上限在 `RewriteKind`）。
    /// 詞彙照帶，人名品牌才不會在改寫時又寫錯。
    /// W2：使用者這次多打的一句要求接在最後（`RewriteKind.systemContent`）。
    func rewrite(
        text: String,
        kind: RewriteKind,
        model: String,
        vocabulary: [String],
        instruction: String? = nil
    ) async throws -> String {
        let base = Self.systemContent(prompt: kind.prompt, vocabulary: vocabulary)
        return try await complete(
            system: RewriteKind.appending(instruction, to: base),
            user: RewriteKind.userContent(text: text),
            model: model
        )
    }

    /// W4 改一段：只送選起來的那段，加上前後各一小段讓模型看得懂在講什麼；回來的只有改好的那段。
    /// 「自己講怎麼改」的那句要求接在最後，跟改寫的補充要求同一套。
    func rewritePassage(
        _ passage: PassageContext,
        kind: PassageRewriteKind,
        model: String,
        vocabulary: [String],
        instruction: String? = nil
    ) async throws -> String {
        let base = Self.systemContent(prompt: kind.prompt, vocabulary: vocabulary)
        return try await complete(
            system: RewriteKind.appending(instruction, to: base),
            user: PassageRewriteKind.userContent(passage),
            model: model
        )
    }

    /// 請 AI 看整篇：只要意見，回來的是 JSON，形狀在 `ReviewResult.parse` 驗。
    func review(
        text: String,
        kind: ReviewKind,
        model: String,
        vocabulary: [String]
    ) async throws -> ReviewResult {
        let content = try await complete(
            system: Self.systemContent(prompt: kind.prompt, vocabulary: vocabulary),
            user: RewriteKind.userContent(text: text),
            model: model,
            responseFormat: kind.responseFormat
        )
        return try ReviewResult.parse(content, kind: kind)
    }

    /// 這趟講了幾件事：文字稿切成編號的單位送出去，只收標題、摘要、段號；正文從原稿接回來。
    func splitTopics(
        text: String,
        model: String,
        vocabulary: [String]
    ) async throws -> TopicSplit {
        let units = TopicUnits.cut(text)
        let content = try await complete(
            system: Self.systemContent(prompt: TopicSplit.prompt, vocabulary: vocabulary),
            user: RewriteKind.userContent(text: TopicUnits.numbered(units)),
            model: model,
            responseFormat: TopicSplit.responseFormat
        )
        return try TopicSplit.parse(content, units: units)
    }

    /// 潤飾、改寫、看整篇、拆篇共用：送一次 chat completions，可重試的錯誤重試，回來的當純文字。
    private func complete(
        system: String,
        user: String,
        model: String,
        responseFormat: ChatResponseFormat? = nil
    ) async throws -> String {
        let request = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: user),
            ],
            reasoningEffort: Self.reasoningEffort,
            responseFormat: responseFormat
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

    static func systemContent(prompt: String, vocabulary: [String]) -> String {
        let words = vocabulary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var content = prompt
        if !words.isEmpty {
            content += "\n\n專有名詞（這些字要寫對）：" + words.joined(separator: "、")
        }
        return content
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
