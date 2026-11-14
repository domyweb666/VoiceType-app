import SwiftUI

/// 待轉錄清單（片 C6）：時間、長度，「刪掉這一個」要先過系統動作表確認（⚠️ 刪檔）。
/// 右滑「整理這一個」只整理那一筆（S2-8，流程檔「可單獨重試」）。從首頁待轉錄列推入。
/// 2026-11-07 統一風格：正在整理的那筆標「整理中」、被拒那行圖示＋紅字、刪不掉用狀態條講。
struct PendingListView: View {
    /// 刪掉一個之後通知首頁重算數字。
    let onChange: () -> Void

    @Environment(TranscriptionQueue.self) private var queue
    @State private var recordings: [PendingRecordings.Recording] = []
    @State private var loadFailed = false
    @State private var deleteFailed = false
    @State private var processFailed = false
    @State private var recordingToDelete: PendingRecordings.Recording?
    @State private var isConfirmingDelete = false

    var body: some View {
        List {
            Section {
                ForEach(recordings) { recording in
                    row(recording)
                        .listRowBackground(Token.Colors.rowBackground)
                        .swipeActions(edge: .leading) {
                            Button("整理這一個") { processOne(recording) }
                                .tint(Token.Colors.link)
                        }
                        .swipeActions {
                            Button("刪除", role: .destructive) {
                                recordingToDelete = recording
                                isConfirmingDelete = true
                            }
                            .tint(Token.Colors.danger)
                        }
                }
            } footer: {
                if !recordings.isEmpty {
                    Text("這些錄音還沒變成文字，有網路、有金鑰時會自己開始整理。左滑可以刪掉一段，刪之前會再問一次。")
                        .font(Token.Fonts.footnote)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .overlay {
            if recordings.isEmpty {
                Text(loadFailed ? "待轉錄清單讀不到，錄音檔都還在。" : "沒有待轉錄的錄音")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Token.Space.xl)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 清單還有東西時 overlay 不出現，刪不掉要另外講，不然按了像沒反應。
            if deleteFailed {
                StatusStrip(glyph: .failed, message: "沒刪掉，錄音還在，再試一次。")
                    .padding(.horizontal, Token.Space.screen)
                    .padding(.bottom, Token.Space.s)
            } else if processFailed {
                StatusStrip(glyph: .failed, message: "這段沒整理成功，錄音還在。有網路、有金鑰時再試一次。")
                    .padding(.horizontal, Token.Space.screen)
                    .padding(.bottom, Token.Space.s)
            }
        }
        .navigationTitle("待轉錄")
        .confirmationDialog(
            "這段還沒轉成文字，刪了就沒有了。",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible,
            presenting: recordingToDelete
        ) { recording in
            Button("刪除這個錄音", role: .destructive) {
                delete(recording)
            }
            Button("取消", role: .cancel) {}
        }
        .task { reload() }
    }

    private func processOne(_ recording: PendingRecordings.Recording) {
        processFailed = false
        Task {
            let outcome = await queue.processOne(recordingAt: recording.url)
            switch outcome {
            case .finished, .polishFailed, .draftNotSaved, nil:
                break
            default:
                processFailed = true
            }
            reload()
            onChange()
        }
    }

    private func row(_ recording: PendingRecordings.Recording) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            HStack(spacing: Token.Space.s) {
                Text(recording.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Token.Fonts.rowTitle)
                    .foregroundStyle(Token.Colors.textPrimary)
                Spacer()
                if isProcessing(recording) {
                    processingBadge
                }
            }
            Text(RecordingSheetView.formatSpoken(recording.durationSeconds))
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
            // 自動整理跳過它，要使用者自己決定刪不刪（不自動刪：檔裡可能有他要的話）。
            if queue.refusedRecordings.contains(recording.id) {
                refusedNote
            }
        }
    }

    /// 流水正在轉或正在潤飾這一筆。
    private func isProcessing(_ recording: PendingRecordings.Recording) -> Bool {
        switch queue.activity {
        case let .transcribing(name, _, _), let .polishing(name):
            name == recording.id
        case .idle:
            false
        }
    }

    private var processingBadge: some View {
        HStack(spacing: Token.Space.xs) {
            ProgressView()
                .tint(Token.Colors.link)
            Text("整理中")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
        }
    }

    /// 圖示＋文字一起出現，顏色不單獨承載意義（使用規則第 4 條）。
    private var refusedNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: Token.Space.s) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Token.Colors.danger)
                .accessibilityHidden(true)
            Text("OpenAI 沒收下這段，自動整理會跳過它。不要的話左滑刪掉。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.danger)
        }
    }

    private func reload() {
        do {
            recordings = try PendingRecordings().list()
            loadFailed = false
        } catch {
            recordings = []
            loadFailed = true
        }
    }

    private func delete(_ recording: PendingRecordings.Recording) {
        do {
            try PendingRecordings().delete(recording)
            recordings.removeAll { $0.id == recording.id }
            deleteFailed = false
            onChange()
        } catch {
            deleteFailed = true
        }
    }
}
