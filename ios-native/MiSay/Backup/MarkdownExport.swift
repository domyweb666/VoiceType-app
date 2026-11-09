import Foundation

/// 方塊 M8：一篇文字稿存成 Markdown 檔（K2），給 Obsidian、Notion 這類在電腦上寫東西的地方用。
/// 檔頭放日期、長度、來源（Obsidian 讀得懂的 YAML），正文就是文字稿，不加標題、不改字。
enum MarkdownExport {
    /// 檔名放開頭幾個字，在資料夾裡一眼認得出是哪篇。
    static let titleCharacterCount = 12
    /// 檔名不能有的字元，換成空白。
    static let forbiddenCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")

    static func fileName(for transcript: Transcript) -> String {
        let date = stamp(transcript.createdAt, format: "yyyy-MM-dd HHmm")
        let opening = transcript.displayText
            .components(separatedBy: forbiddenCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
            .prefix(titleCharacterCount)
        return opening.isEmpty ? "\(date).md" : "\(date) \(opening).md"
    }

    static func content(for transcript: Transcript) -> String {
        let minutes = max(1, Int((transcript.durationSeconds / 60).rounded()))
        let header = [
            "---",
            "date: \(stamp(transcript.createdAt, format: "yyyy-MM-dd HH:mm"))",
            "length: \(minutes) 分鐘",
            "source: 米說",
            "---",
        ].joined(separator: "\n")
        return header + "\n\n" + transcript.displayText + "\n"
    }

    private static func stamp(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
