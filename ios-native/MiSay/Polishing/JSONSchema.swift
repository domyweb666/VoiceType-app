import Foundation

/// 請模型照這個形狀回 JSON（OpenAI 的 json_schema strict，2026-11-24 查證）。
/// strict 規定每個物件都要 `additionalProperties: false`、欄位全部列在 `required`。只做用得到的四種。
indirect enum JSONSchema: Encodable {
    case text
    case integer
    case list(item: JSONSchema, max: Int? = nil)
    case object([String: JSONSchema])

    private enum CodingKeys: String, CodingKey {
        case type
        case items
        case maxItems
        case properties
        case required
        case additionalProperties
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text:
            try container.encode("string", forKey: .type)
        case .integer:
            try container.encode("integer", forKey: .type)
        case let .list(item, max):
            try container.encode("array", forKey: .type)
            try container.encode(item, forKey: .items)
            try container.encodeIfPresent(max, forKey: .maxItems)
        case let .object(properties):
            try container.encode("object", forKey: .type)
            try container.encode(properties, forKey: .properties)
            try container.encode(properties.keys.sorted(), forKey: .required)
            try container.encode(false, forKey: .additionalProperties)
        }
    }
}
