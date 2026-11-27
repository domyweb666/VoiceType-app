import Foundation

/// 方塊 M8：一篇文字稿存成 Markdown 檔（K2），給 Obsidian、Notion 這類在電腦上寫東西的地方用。
/// 檔頭放標題（有的話）、日期、長度、來源（Obsidian 讀得懂的 YAML），正文就是文字稿，不加標題、不改字。
enum MarkdownExport {
    /// 沒有標題的，檔名放開頭幾個字，在資料夾裡一眼認得出是哪篇。
    static let titleCharacterCount = 12
    /// 標題放進檔名最多幾個字：檔名有長度上限，中文一個字佔三格。
    static let fileNameTitleLength = 40
    /// 檔名不能有的字元，換成空白。
    static let forbiddenCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")

    static func fileName(for transcript: Transcript) -> String {
        let date = stamp(transcript.createdAt, format: "yyyy-MM-dd HHmm")
        let name = title(of: transcript).map { fileNamePart($0, limit: fileNameTitleLength) }
            ?? fileNamePart(transcript.displayText, limit: titleCharacterCount)
        return name.isEmpty ? "\(date).md" : "\(date) \(name).md"
    }

    /// 使用者取的標題，一行；沒取或只有空白是 nil。
    static func title(of transcript: Transcript) -> String? {
        let title = (transcript.title ?? "")
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }

    /// 換掉檔名不能有的字元，只留前面幾個字。
    static func fileNamePart(_ text: String, limit: Int) -> String {
        let cleaned = text
            .components(separatedBy: forbiddenCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return String(cleaned.prefix(limit))
    }

    static func content(for transcript: Transcript) -> String {
        let minutes = max(1, Int((transcript.durationSeconds / 60).rounded()))
        var header = ["---"]
        if let name = title(of: transcript) {
            header.append("title: \(quoted(name))")
        }
        header += [
            "date: \(stamp(transcript.createdAt, format: "yyyy-MM-dd HH:mm"))",
            "length: \(minutes) 分鐘",
            "source: 芋音",
            "---",
        ]
        return header.joined(separator: "\n") + "\n\n" + transcript.displayText + "\n"
    }

    /// 標題裡的冒號、井號會讓 YAML 讀壞，所以一律包起來。
    private static func quoted(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func stamp(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
