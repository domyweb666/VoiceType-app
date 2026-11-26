import SwiftUI

/// 詳情頁右上的「⋯」（K 組塊拆檔：主檔快到 300 行）。
/// 2026-11-26 米：「那些選單功能，我覺得太複雜了」。第一層只留常用的，其餘收進「其他」，一項都沒刪：
/// 大綱與尋找拿掉，打字時右上那顆就是；潤飾說明搬到「其他」最下面。
extension TranscriptDetailView {
    var moreMenu: some View {
        Menu {
            // K3：接著錄，錄好的那段接在這篇後面，不離開這頁（`+RecordHere`）。
            // 還沒整理的篇沒有鍵盤上那排，只有這裡錄得到。
            Button {
                appendRecording()
            } label: {
                Label("接著錄", systemImage: "mic.badge.plus")
            }
            // 這篇還在整理時接上去，整理完存回來會蓋掉接上去的字（K 審查）。
            .disabled(isLocked)
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
            sourceMenuItem
            threadsPartsMenuItem
            openSourceMenuItem
            otherMenu
            Divider()
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label("刪除這篇", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("更多")
    }

    /// 不常用的收在這裡，動作與能不能按都照搬。
    private var otherMenu: some View {
        Menu {
            // W6：標籤，清單可以照標籤篩。
            Button {
                knownTags = Self.loadKnownTags()
                showsTags = true
            } label: {
                Label(Self.tagMenuTitle(transcript.tags ?? []), systemImage: "tag")
            }
            writingMenuItems
                .disabled(isLocked)
            splitMenuItem
            // 片 F4：看得出這篇用哪種潤飾、哪個模型。只是說明，按不下去，所以放最下面。
            // Y5：改寫來的講改寫成哪一種、當時的補充要求；拆出來的也講一聲。
            if transcript.isDerived {
                derivedNoteSection
            } else if let model = transcript.polishModel {
                Section {
                    Text(Self.polishNote(model: model, style: transcript.polishStyle))
                }
            }
        } label: {
            Label("其他", systemImage: "ellipsis.circle")
        }
    }

    /// Y6：三種看法一種都沒有就不出現。
    @ViewBuilder
    private var sourceMenuItem: some View {
        let hasRecording = RetainedRecordings().exists(for: transcript.id)
        if !SourceSheet.modes(for: transcript, hasRecording: hasRecording).isEmpty {
            Button {
                showsSource = true
            } label: {
                Label("錄音與原稿", systemImage: "waveform")
            }
        }
    }

    var sourceSheet: some View {
        SourceSheet(
            transcript: transcript,
            recordingURL: RetainedRecordings().existingURL(for: transcript.id),
            onRetranscribe: retranscribe
        )
    }
}
