import Foundation

/// 送給 chat completions 的正文。從 `Polisher` 拆出來：型別最多巢一層，`CodingKeys` 放不進去。
struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let reasoningEffort: String
    /// 要 JSON 的才帶（請 AI 看整篇、拆篇）；nil 時整個欄位不送（Encodable 合成的會略過 nil）。
    let responseFormat: ChatResponseFormat?

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case reasoningEffort = "reasoning_effort"
        case responseFormat = "response_format"
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatResponseFormat: Encodable {
    let type = "json_schema"
    let jsonSchema: NamedSchema

    private enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }

    struct NamedSchema: Encodable {
        /// 只能是英數、底線、減號，64 字以內。
        let name: String
        let strict = true
        let schema: JSONSchema
    }
}
