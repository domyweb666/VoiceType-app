import SwiftUI

/// 詳情頁右上的「⋯」（K 組塊拆檔：主檔快到 300 行）：潤飾說明、看口語稿、接著錄、從錄音重新轉錄、刪除。
extension TranscriptDetailView {
    var moreMenu: some View {
        Menu {
            // 片 F4：看得出這篇用哪種潤飾、哪個模型。只是說明，按不下去。
            if let model = transcript.polishModel {
                Section {
                    Text(Self.polishNote(model: model, style: transcript.polishStyle))
                }
            }
            if transcript.draftText != nil {
                Button {
                    showsRawText = true
                } label: {
                    Label("看口語稿", systemImage: "waveform")
                }
            }
            // K3：接著錄，錄好的那段接在這篇後面。
            Button {
                appendRecording()
            } label: {
                Label("接著錄", systemImage: "mic.badge.plus")
            }
            // S2-5：錄音還留著才有這顆（文字稿存好後留 7 天）。接著錄過的篇錄音不只一段，不給。
            if transcript.isCombined != true, RetainedRecordings().exists(for: transcript.id) {
                Button {
                    isConfirmingRetranscribe = true
                } label: {
                    Label("從錄音重新轉錄", systemImage: "arrow.clockwise")
                }
            }
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label("刪除這篇文字稿", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("更多")
    }

    /// K3：先存好手上改的字、退出這頁，再請分頁列切到錄音頁開錄。退出是為了不留一份舊的在畫面上。
    func appendRecording() {
        flushAutosave()
        RecordingLauncher.shared.request = .append(to: transcript.id)
        dismiss()
    }

    /// 這篇在存檔裡比畫面上的新（接著錄、重轉、別處整理完）：換成存檔裡的。正在打字或整理時不換。
    func reloadFromStore() {
        guard !isPolishing, !isEditing else {
            return
        }
        let transcripts = (try? TranscriptStore().loadAll().transcripts) ?? []
        guard let stored = transcripts.first(where: { $0.id == transcript.id }),
              stored.updatedAt > transcript.updatedAt
        else {
            return
        }
        transcript = stored
        draftEdit = stored.draftText ?? ""
    }
}
