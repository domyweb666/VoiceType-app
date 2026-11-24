import SwiftUI

/// 右上的「匯出」（2026-11-24 Y1）：複製、分享、存檔都收進 `ExportSheet`。
extension TranscriptDetailView {
    var exportButton: some View {
        Button {
            flushAutosave()
            flushTitle()
            showsExport = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(currentText.isEmpty)
        .accessibilityLabel("匯出")
    }

    /// 帶出去的是編輯框裡現在的字：剛才那次存檔失敗，匯出的也不能是舊的。
    var exportSheet: some View {
        var exported = transcript
        if transcript.draftText != nil {
            exported.draftText = draftEdit
        }
        return ExportSheet(transcript: exported)
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
