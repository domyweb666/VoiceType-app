import Foundation

/// 選起來要改的那段，加上前後各一小段。從整篇文字稿與選取範圍切出來。
struct PassageContext: Equatable {
    let text: String
    let before: String
    let after: String

    init(text: String, before: String, after: String) {
        self.text = text
        self.before = before
        self.after = after
    }

    /// `offset`、`length` 都是第幾個字（Character），不是 String.Index：字被改過之後，舊的 Index 不能再拿來用。
    init?(in fullText: String, offset: Int, length: Int) {
        guard offset >= 0, length > 0, offset + length <= fullText.count else {
            return nil
        }
        let start = fullText.index(fullText.startIndex, offsetBy: offset)
        let end = fullText.index(start, offsetBy: length)
        text = String(fullText[start ..< end])
        before = String(fullText[..<start].suffix(PassageRewriteKind.contextCharacters))
        after = String(fullText[end...].prefix(PassageRewriteKind.contextCharacters))
    }

    /// 換上：字還在原本的位置就換那裡；等的時候前面被改過，就找這段第一次出現的地方；找不到回 nil，不換。
    static func replacing(
        _ original: String,
        at offset: Int,
        with replacement: String,
        in fullText: String
    ) -> String? {
        var result = fullText
        if offset >= 0, offset + original.count <= fullText.count {
            let start = fullText.index(fullText.startIndex, offsetBy: offset)
            let end = fullText.index(start, offsetBy: original.count)
            if fullText[start ..< end] == original {
                result.replaceSubrange(start ..< end, with: replacement)
                return result
            }
        }
        guard let found = fullText.range(of: original) else {
            return nil
        }
        result.replaceSubrange(found, with: replacement)
        return result
    }
}
