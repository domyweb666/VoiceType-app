import SwiftUI

/// 詳情頁右上的「⋯」（K 組塊拆檔：主檔快到 300 行）：最上面是潤飾說明，
/// 2026-11-24 Y6 起照「寫、出、查來源、刪」分四組，中間隔線。
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
            writingMenuItems
            // K3：接著錄，錄好的那段接在這篇後面，不離開這頁（`+RecordHere`）。
            Button {
                appendRecording()
            } label: {
                Label("接著錄", systemImage: "mic.badge.plus")
            }
            // 這篇還在整理時接上去，整理完存回來會蓋掉接上去的字（K 審查）。
            .disabled(isPolishing)
            reviewMenuItem
            // W6：標籤，清單可以照標籤篩。
            Button {
                showsTags = true
            } label: {
                Label(Self.tagMenuTitle(transcript.tags ?? []), systemImage: "tag")
            }
            Divider()
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
            threadsPartsMenuItem
            Divider()
            sourceMenuItem
            openSourceMenuItem
            Divider()
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
