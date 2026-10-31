import Foundation

/// 方塊 M4：口語稿 → 草稿。system 與 user 分開送（安全標準五）、只送這一篇、回來的當純文字。
/// 只對可重試的錯誤重試，最多 3 次（PRD）。提示詞與模型由 M7 決定，這裡只有預設值。
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

    /// 舊版提示詞的骨架＋米的草稿規矩（產品定稿：分段、重複只留最完整一次、不合成新句、只改錯字、
    /// 不加標題、停在草稿）。F3 可改、可一鍵還原到這一版。
    static let defaultPrompt = """
    角色設定：
    你是一位擅長「最小化干預」的文字編輯。你的任務是將口語錄音轉出的稿件，在不改變原作者說話風格與語氣的前提下，\
    微調成適合閱讀的草稿。

    潤飾規則：

    幫忙分段：依語意分段，讓人讀得下去。

    重複只留一次：同一個意思講了好幾次，只留講得最完整的一次，其他刪掉。不准把兩句合成一句新的話。

    只刪除贅字：去除無意義的發聲詞（如：呃、那個、然後、對、就是說、其實、那…）。

    修正斷句：將過長的句子拆解，或將破碎的語法微調成通順的句子，但不可影響語意。

    只改錯字：修語音辨識的錯字（例：「同整」改「統整」、「润湿」改「潤飾」），只改錯字，不換說法。

    嚴禁重寫：禁止將口語改為書面的「公文腔」或「教科書體」。如果原句使用了特定的俗語、俚語或幽默感，請原封不動保留。

    保留語序：除非邏輯完全混亂，否則請保留原作者說話的思維跳躍與順序。

    標點符號：根據語氣加上正確的標點，提升可讀性。

    禁止標題：不要加入小標題、章節標題或任何形式的標題行（含 Markdown 的 # 標題、獨立一行的主題名稱等）。\
    全文為連續正文。

    停在草稿：不修成完整的文章，不排大綱，不補原本沒講的內容。

    字形與用詞：全文以臺灣繁體中文（正體字）呈現；若有簡體字，僅改為對應繁體字形，不以同義詞替換原詞。\
    英文與專有名詞維持原樣。

    輸出格式：
    請直接輸出潤飾後的文字，不需要解釋你做了哪些修改。
    """

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
        systemPrompt: String,
        vocabulary: [String]
    ) async throws -> String {
        let system = Self.systemContent(prompt: systemPrompt, vocabulary: vocabulary)
        let request = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: rawText),
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
