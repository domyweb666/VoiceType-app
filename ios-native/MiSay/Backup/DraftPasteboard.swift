import UIKit
import UniformTypeIdentifiers

/// 複製文字稿（2026-11-24 Y1）：同一個項目放兩種格式，只認純文字的 App 拿到沒有記號的字，
/// 能排版的地方（Notion、部落格後台、備忘錄）拿到粗體、標題與清單。
enum DraftPasteboard {
    /// 有些 App 讀 HTML 沒看到編碼會當成西歐文字，中文變亂碼。
    private static let charsetTag = "<meta charset=\"utf-8\">"

    @MainActor
    static func copy(_ markdown: String) {
        UIPasteboard.general.setItems(items(for: markdown))
    }

    /// 給 Obsidian 這類自己認得 Markdown 的地方：記號原樣帶走。
    @MainActor
    static func copyMarkdown(_ markdown: String) {
        UIPasteboard.general.string = markdown
    }

    /// 純文字放 String，貼上的那邊用 `string` 才拿得到；HTML 放 Data，不會被當成字貼出一堆標籤。
    static func items(for markdown: String) -> [[String: Any]] {
        let html = charsetTag + HTMLExport.html(from: markdown)
        let item: [String: Any] = [
            UTType.utf8PlainText.identifier: PlainTextExport.text(from: markdown),
            UTType.html.identifier: Data(html.utf8),
        ]
        return [item]
    }
}
