import SwiftUI

/// 待轉錄清單（片 C6）：時間、長度，「刪掉這一個」要先過系統動作表確認（⚠️ 刪檔）。
/// 「轉錄這一個」是組塊 D。從首頁待轉錄列推入。
struct PendingListView: View {
    /// 刪掉一個之後通知首頁重算數字。
    let onChange: () -> Void

    @State private var recordings: [PendingRecordings.Recording] = []
    @State private var loadFailed = false
    @State private var deleteFailed = false
    @State private var recordingToDelete: PendingRecordings.Recording?
    @State private var isConfirmingDelete = false

    var body: some View {
        List(recordings) { recording in
            VStack(alignment: .leading, spacing: Token.Space.xs) {
                Text(recording.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Token.Fonts.rowTitle)
                    .foregroundStyle(Token.Colors.textPrimary)
                Text(RecordingSheetView.formatSpoken(recording.durationSeconds))
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
            .listRowBackground(Token.Colors.rowBackground)
            .swipeActions {
                Button("刪除", role: .destructive) {
                    recordingToDelete = recording
                    isConfirmingDelete = true
                }
                .tint(Token.Colors.danger)
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
                Text("沒刪掉，錄音還在，再試一次。")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.danger)
                    .padding(Token.Space.l)
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
