import SwiftUI

/// 詳情頁右上的「⋯」（K 組塊拆檔：主檔快到 300 行）：潤飾說明、看口語稿、看 AI 改了什麼、改寫成其他格式、接著錄、
/// 從錄音重新轉錄、刪除。
extension TranscriptDetailView {
    var moreMenu: some View {
        Menu {
            // 片 F4：看得出這篇用哪種潤飾、哪個模型。只是說明，按不下去。
            // Y5：改寫來的講改寫成哪一種、當時的補充要求。
            if transcript.isDerived {
                derivedNoteSection
            } else if let model = transcript.polishModel {
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
            derivedMenuItems
            // W1：改寫成別的格式，另外存成一篇。整理中不給：文字稿還沒定。
            Button {
                openRewrites()
            } label: {
                Label(
                    Self.rewriteMenuTitle(copies: rewriteCount),
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
            // K3：接著錄，錄好的那段接在這篇後面。
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

    /// K3：先存好手上改的字、退出這頁，再請分頁列切到錄音頁開錄。退出是為了不留一份舊的在畫面上。
    func appendRecording() {
        flushAutosave()
        isLeavingToRecord = true
        RecordingLauncher.shared.request = .append(target: transcript.id, insertion: nil)
        dismiss()
    }

    /// 2026-11-09 米：打字時按麥克風，錄好的那段插在游標的位置（中間補內容）。
    /// 位置照存好的那份字記，所以先存；存不進去就不走（狀態條已經講了），不然位置會對不上。
    func insertRecording(at offset: Int) {
        flushAutosave()
        guard draftEdit == transcript.draftText else {
            return
        }
        isEditing = false
        isLeavingToRecord = true
        let point = InsertionPoint(offset: offset, in: draftEdit)
        RecordingLauncher.shared.request = .append(target: transcript.id, insertion: point)
        dismiss()
    }

    /// 這篇在存檔裡比畫面上的新（接著錄、重轉、別處整理完）：換成存檔裡的。正在打字或整理時不換。
    func reloadFromStore() {
        let transcripts = (try? TranscriptStore().loadAll().transcripts) ?? []
        derived.refresh(sourceID: transcript.id, from: transcripts)
        guard !isPolishing, !isEditing,
              let stored = transcripts.first(where: { $0.id == transcript.id }),
              stored.updatedAt > transcript.updatedAt
        else {
            return
        }
        transcript = stored
        draftEdit = stored.draftText ?? ""
    }
}
