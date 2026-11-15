import SwiftUI

/// 2026-11-15 米：光用手機就要能在編輯區打出長文。文字稿清單右上多一顆「新文稿」，開一張空白頁直接寫，
/// 不用先錄音。一個字都沒寫就離開，那篇不會留在清單（詳情頁 `discardIfBlank`）。
extension TranscriptListView {
    var newDraftButton: some View {
        Button(action: startNewDraft) {
            Image(systemName: "square.and.pencil")
        }
        .accessibilityLabel("新文稿")
        .tint(Token.Colors.link)
        .disabled(isSelecting)
    }

    /// 先存再開：打字時按「在這裡接著錄」要找得到這篇。
    func startNewDraft() {
        let draft = Transcript.blankDraft()
        do {
            try TranscriptStore().save(draft)
        } catch {
            newDraftFailed = true
            return
        }
        transcripts.insert(draft, at: 0)
        openedTranscript = draft
    }
}
