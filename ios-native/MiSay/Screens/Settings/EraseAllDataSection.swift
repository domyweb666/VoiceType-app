import SwiftUI
import VeggieKit

/// 設定 →「資料」區最後一列「清除所有資料」（S2-9，安全標準六 🔴；2026-11-26 照蔬菜家族規格從進階搬上來、改名）：
/// 文字稿（含垃圾桶）、待轉錄的錄音、留著的錄音、錄到一半的檔、進度檔、診斷紀錄一起刪，
/// 以前加密文字稿的那把舊鑰匙也刪；外觀、觸覺回饋回到預設（準則 3-10）。
/// OpenAI 金鑰另有鈕，不動；其他設定與詞彙不動。
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
            Button(role: .destructive) {
                resultMessage = nil
                isConfirming = true
            } label: {
                VeggieRow(icon: "trash", title: VeggieText.eraseAll, destructive: true)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            // 自己畫的列不會跟著停用變淡，要自己淡下去，不然看不出按不了。
            .opacity(isBusy ? Token.Motion.disabledOpacity : 1)
            .confirmationDialog(
                VeggieText.eraseAll + "？",
                isPresented: $isConfirming,
                titleVisibility: .visible
            ) {
                Button("全部刪除", role: .destructive, action: erase)
                Button("取消", role: .cancel) {}
            } message: {
                Text(Self.confirmNote)
            }
        } footer: {
            if let footerText {
                Text(footerText)
                    .font(Token.Fonts.footnote)
            }
        }
        .font(Token.Fonts.body)
        .listRowBackground(Token.Colors.rowBackground)
    }

    static let confirmNote = "文字稿（連垃圾桶）、還沒轉的錄音、留著的錄音和診斷紀錄都會刪掉，救不回來。"
        + "外觀和觸覺回饋回到預設；OpenAI 金鑰和其他設定不會動，已經匯出或自動備份出去的檔也還在。"

    /// 準則 3-10：外觀、觸覺回饋是家族共用的偏好，清資料時一起回到預設。畫面上的外觀由呼叫的人重套。
    static let resetPreferenceKeys = [Appearance.storageKey, VeggieHaptics.storageKey]

    private var isBusy: Bool {
        recorder.isRecording || queue.activity != .idle || queue.isProcessingPending
            || !queue.inFlight.isEmpty
    }

    /// 2026-11-26 米（QC-0014）：不放說明，只講結果和按鈕為什麼按不了。
    private var footerText: String? {
        if let resultMessage {
            return resultMessage
        }
        return isBusy ? "正在錄音或整理，等它做完才能刪。" : nil
    }

    private func erase() {
        do {
            try Self.eraseAll()
            resultMessage = "全部刪掉了。"
        } catch {
            resultMessage = "有些沒刪掉，再按一次試試。"
        }
        // 外觀的偏好已經清掉，視窗要跟著換回跟隨系統，不然要重開才看得到。
        Appearance.stored.apply()
    }

    /// 刪資料夾裡的東西，不刪資料夾本身：其他地方隨時會再寫進來，資料夾要在。
    /// 垃圾桶是 Transcripts 裡的子資料夾，整個一起刪。
    /// 一個檔刪不掉不停，其他照刪，最後才說有沒有漏；舊鑰匙最後刪，沒有鑰匙也算成功。
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
        // 之前寫出去的備份從此不歸自動備份管，之後的新備份不會把它們擠掉。
        AutoBackup.shared.forgetWrittenFiles()
        for key in resetPreferenceKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        try TranscriptEncryptionKeyStore().delete()
        guard isComplete else {
            throw Failure.incomplete
        }
    }
}
