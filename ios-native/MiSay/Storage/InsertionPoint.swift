import Foundation

/// 2026-11-09 米：打字時在游標的位置接著錄（中間要補內容，不是只能接在最後面）。
/// 錄音、整理要一段時間，這段時間字可能被改過，所以除了第幾個字，也記住游標前後各一小段字。
/// 插回去時先看原本的位置對不對得上，對不上就照前後文找；找不到或找到好幾處不猜，交給呼叫的接在最後面。
struct InsertionPoint: Equatable {
    /// 第幾個字（Character）。
    let offset: Int
    let before: String
    let after: String

    /// 前後各記幾個字：短了容易撞到別處一樣的字，長了游標附近一改就對不上。
    static let contextLength = 20

    init(offset: Int, in text: String) {
        let characters = Array(text)
        let clamped = min(max(0, offset), characters.count)
        self.offset = clamped
        before = String(characters[max(0, clamped - Self.contextLength) ..< clamped])
        after = String(
            characters[clamped ..< min(characters.count, clamped + Self.contextLength)]
        )
    }

    /// 在這份字裡要插在第幾個字；對不上回 nil。
    func resolvedOffset(in text: String) -> Int? {
        let characters = Array(text)
        let beforeCharacters = Array(before)
        let afterCharacters = Array(after)
        if matches(beforeCharacters, afterCharacters, at: offset, in: characters) {
            return offset
        }
        guard !beforeCharacters.isEmpty || !afterCharacters.isEmpty,
              characters.count >= beforeCharacters.count + afterCharacters.count
        else {
            return nil
        }
        let positions = beforeCharacters.count ... characters.count - afterCharacters.count
        let candidates = positions.filter {
            matches(beforeCharacters, afterCharacters, at: $0, in: characters)
        }
        return candidates.count == 1 ? candidates.first : nil
    }

    /// 把一段字插在這個位置，前後跟原本的字各隔一個空行（已經有換行就補到一個空行為止）。
    /// 回 nil 表示找不到位置。
    func inserting(_ block: String, into text: String) -> String? {
        guard let position = resolvedOffset(in: text) else {
            return nil
        }
        let characters = Array(text)
        let left = String(characters[..<position])
        let right = String(characters[position...])
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        return left + Self.gap(after: left) + trimmed + Self.gap(before: right) + right
    }

    private func matches(
        _ beforeCharacters: [Character],
        _ afterCharacters: [Character],
        at position: Int,
        in characters: [Character]
    ) -> Bool {
        guard position >= beforeCharacters.count,
              position + afterCharacters.count <= characters.count
        else {
            return false
        }
        return characters[position - beforeCharacters.count ..< position]
            .elementsEqual(beforeCharacters)
            && characters[position ..< position + afterCharacters.count]
            .elementsEqual(afterCharacters)
    }

    private static func gap(after left: String) -> String {
        if left.isEmpty || left.hasSuffix("\n\n") {
            return ""
        }
        return left.hasSuffix("\n") ? "\n" : "\n\n"
    }

    private static func gap(before right: String) -> String {
        if right.isEmpty || right.hasPrefix("\n\n") {
            return ""
        }
        return right.hasPrefix("\n") ? "\n" : "\n\n"
    }
}
