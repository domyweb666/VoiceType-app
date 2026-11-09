import SwiftUI

/// 文字稿頁右上「匯入音檔」（K7）：從「檔案」選一個音檔，轉好放進待轉錄，有網路、有金鑰時自己整理。
struct ImportAudioButton: View {
    @Environment(TranscriptionQueue.self) private var queue
    @State private var isImporting = false
    @State private var message: String?

    var body: some View {
        Button("匯入音檔", systemImage: "square.and.arrow.down") {
            isImporting = true
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio]) { result in
            guard case let .success(url) = result else {
                return
            }
            message = Self.importAndStart(url, queue: queue)
        }
        .alert(
            message ?? "",
            isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
        ) {
            Button("好") {}
        }
    }

    /// 從「檔案」選的、從語音備忘錄分享進來的，都走這裡。回要跟使用者講的那句。
    @MainActor
    static func importAndStart(_ url: URL, queue: TranscriptionQueue) -> String {
        do {
            _ = try AudioImport.importAudio(from: url)
        } catch {
            return "這個檔讀不出聲音，換一個試試。原本的檔沒有動。"
        }
        queue.startPendingRun()
        return "收進待轉錄了。有網路、有金鑰時會自己整理。"
    }
}
