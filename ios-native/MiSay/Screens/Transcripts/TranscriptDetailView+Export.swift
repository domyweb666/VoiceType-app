import SwiftUI

/// K2「⋯ → 存成 Markdown」：存到選過的資料夾；還沒選過，先跳「檔案」選一個。
/// Notion 走右上的分享（系統分享表單），不接 Notion 的帳號。
extension TranscriptDetailView {
    func saveMarkdown() {
        flushAutosave()
        guard MarkdownFolder().folderName != nil else {
            isPickingMarkdownFolder = true
            return
        }
        do {
            let name = try MarkdownFolder().save(transcript)
            showNote("存好了：\(name)")
        } catch MarkdownFolder.Failure.cannotAccess, MarkdownFolder.Failure.noFolder {
            // 資料夾不見了或權限沒了：請使用者重選。
            isPickingMarkdownFolder = true
        } catch {
            showNote("沒存進去，那個資料夾可能滿了或不能寫，換一個試試。")
        }
    }

    func pickedMarkdownFolder(_ result: Result<URL, Error>) {
        guard case let .success(folder) = result else {
            return
        }
        do {
            try MarkdownFolder().remember(folder)
        } catch {
            showNote("打不開這個資料夾，換一個試試。")
            return
        }
        saveMarkdown()
    }

    /// 底下那行講一下就收：跟「已複製」一樣停 2 秒。
    func showNote(_ message: String) {
        note = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if note == message {
                note = nil
            }
        }
    }
}
