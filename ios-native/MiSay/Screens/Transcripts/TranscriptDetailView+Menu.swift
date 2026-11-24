import SwiftUI

/// 詳情頁右上的「⋯」（K 組塊拆檔：主檔快到 300 行）：潤飾說明、看口語稿、看 AI 改了什麼、改寫成其他格式、接著錄、
/// 從錄音重新轉錄、刪除。
extension TranscriptDetailView {
    var moreMenu: some View {
        Menu {
            // 片 F4：看得出這篇用哪種潤飾、哪個模型。只是說明，按不下去。
            if let model = transcript.polishModel {
                Section {
                    Text(Self.polishNote(model: model, style: transcript.polishStyle))
                }
            }
            // 自己打的新文稿沒有口語稿，這兩顆不出現。
            if transcript.draftText != nil, !transcript.rawText.isEmpty {
                Button {
                    rawSheetStartsWithDiff = false
                    showsRawText = true
                } label: {
                    Label("看口語稿", systemImage: "waveform")
                }
                // W3：跟口語稿逐字比，看 AI 刪了什麼、加了什麼。
                Button {
                    rawSheetStartsWithDiff = true
                    showsRawText = true
                } label: {
                    Label("看 AI 改了什麼", systemImage: "text.badge.minus")
                }
            }
            writingMenuItems
            // W1：改寫成別的格式，存成這篇底下的另一份。整理中不給：文字稿還沒定。
            Button {
                showsRewrites = true
            } label: {
                Label(
                    Self.rewriteMenuTitle(copies: transcript.rewrites?.count ?? 0),
                    systemImage: "arrow.triangle.branch"
                )
            }
            .disabled(isPolishing || currentText.isEmpty)
            reviewMenuItem
            // W6：標籤，清單可以照標籤篩。
            Button {
                showsTags = true
            } label: {
                Label(Self.tagMenuTitle(transcript.tags ?? []), systemImage: "tag")
            }
            // K5、K6：錄音還留著或標過重點，才有這頁。
            let hasMarks = !(transcript.marks ?? []).isEmpty
            if RetainedRecordings().exists(for: transcript.id) || hasMarks {
                Button {
                    showsOriginalAudio = true
                } label: {
                    Label("聽原音與重點", systemImage: "headphones")
                }
            }
            // K3：接著錄，錄好的那段接在這篇後面（`+RecordHere`）。
            Button {
                appendRecording()
            } label: {
                Label("接著錄", systemImage: "mic.badge.plus")
            }
            // 這篇還在整理時接上去，整理完存回來會蓋掉接上去的字（K 審查）。
            .disabled(isPolishing)
            // S2-5：錄音還留著才有這顆（文字稿存好後留 7 天）。接著錄過的篇錄音不只一段，不給。
            if transcript.combinedAt == nil, RetainedRecordings().exists(for: transcript.id) {
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

    /// 這頁不在畫面上時，存檔可能被換過（接著錄、重轉、別處整理完）：回來一律換成存檔裡的，再登記成正開著。
    /// 不比 `updatedAt`：存檔只記到秒，同一秒裡接上去的會看不出來。
    /// 手上有還沒存進去的字（上次存檔失敗）就留著手上的，存檔裡那份下次存之前先留成一版。
    func reloadFromStore() {
        guard !isPolishing else {
            return
        }
        let transcripts = (try? TranscriptStore().loadAll().transcripts) ?? []
        guard let stored = transcripts.first(where: { $0.id == transcript.id }) else {
            return
        }
        let keepsHand = hasUnsavedDraft
        transcript = stored
        if keepsHand {
            versionDueAt = nil
        } else {
            draftEdit = stored.draftText ?? ""
        }
    }
}
