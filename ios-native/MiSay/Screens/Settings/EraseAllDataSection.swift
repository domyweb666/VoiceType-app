import SwiftUI

/// 設定 → 進階 →「刪除全部資料」（S2-9，安全標準六 🔴）：文字稿、待轉錄的錄音、留著的錄音、錄到一半的檔、
/// 進度檔、診斷紀錄一起刪，加密文字稿的那把鑰匙也刪。OpenAI 金鑰另有鈕，不動；設定與詞彙不動。
/// 一定先過確認框；正在錄音或整理時不給按，免得刪到一半又被寫回去。
struct EraseAllDataSection: View {
    enum Failure: Error, Equatable {
        case incomplete
    }

    @Environment(TranscriptionQueue.self) private var queue
    @Environment(Recorder.self) private var recorder
    @State private var isConfirming = false
    @State private var resultMessage: String?

    var body: some View {
        Section {
            Button("刪除全部資料", role: .destructive) {
                resultMessage = nil
                isConfirming = true
            }
            .disabled(isBusy)
            .confirmationDialog(
                "刪除全部資料？",
                isPresented: $isConfirming,
                titleVisibility: .visible
            ) {
                Button("全部刪除", role: .destructive, action: erase)
                Button("取消", role: .cancel) {}
            } message: {
                Text("文字稿、還沒轉的錄音、留著的錄音和診斷紀錄都會刪掉，救不回來。OpenAI 金鑰和設定不會動。")
            }
        } footer: {
            Text(footerText)
                .font(Token.Fonts.footnote)
        }
        .font(Token.Fonts.body)
        .listRowBackground(Token.Colors.rowBackground)
    }

    private var isBusy: Bool {
        recorder.isRecording || queue.activity != .idle
    }

    private var footerText: String {
        if let resultMessage {
            return resultMessage
        }
        return isBusy ? "正在錄音或整理，等它做完才能刪。" : "要先匯出備份的話，在上面。"
    }

    private func erase() {
        do {
            try Self.eraseAll()
            resultMessage = "全部刪掉了。"
        } catch {
            resultMessage = "有些沒刪掉，再按一次試試。"
        }
    }

    /// 刪資料夾裡的東西，不刪資料夾本身：其他地方隨時會再寫進來，資料夾要在。
    /// 一個檔刪不掉不停，其他照刪，最後才說有沒有漏；鑰匙最後刪，漏掉的文字稿也就讀不出來了。
    static func eraseAll() throws {
        let fileManager = FileManager.default
        let directories = try [
            TranscriptStore().directoryURL(),
            PendingRecordings().directoryURL(),
            RetainedRecordings().directoryURL(),
            Recorder.inProgressDirectoryURL(),
        ]
        var isComplete = true
        for directory in directories {
            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else {
                isComplete = false
                continue
            }
            for file in files {
                do {
                    try fileManager.removeItem(at: file)
                } catch {
                    isComplete = false
                }
            }
        }
        DiagnosticLog.shared.deleteAll()
        try TranscriptEncryptionKeyStore().delete()
        guard isComplete else {
            throw Failure.incomplete
        }
    }
}
