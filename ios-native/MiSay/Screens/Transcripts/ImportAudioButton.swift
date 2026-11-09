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
            Task { message = await Self.importAndStart(url, queue: queue) }
        }
        .alert(
            message ?? "",
            isPresented: Binding(
                get: { message != nil },
                set: { isShown in
                    if !isShown {
                        message = nil
                    }
                }
            )
        ) {
            Button("好") {}
        }
    }

    /// 從「檔案」選的、從語音備忘錄分享進來的，都走這裡。回要跟使用者講的那句。
    /// 轉檔放背景：一小時的 Podcast 要十幾秒，放在畫面那條線上會卡住，冷啟動時還可能被系統殺掉。
    @MainActor
    static func importAndStart(_ url: URL, queue: TranscriptionQueue) async -> String {
        let imported = await Task.detached(priority: .userInitiated) {
            try? AudioImport.importAudio(from: url)
        }.value
        guard imported != nil else {
            return "這個檔讀不出聲音，換一個試試。原本的檔沒有動。"
        }
        queue.startPendingRun()
        return "收進待轉錄了。有網路、有金鑰時會自己整理。"
    }
}
