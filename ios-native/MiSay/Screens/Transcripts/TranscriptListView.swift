import SwiftUI

/// 「文字稿」推入頁（片 D7）：歷史篇最新在上，點一列開詳情。搜尋是 E6，分組與線框等設計線補。
/// 讀不到的篇數照 PRD 說「原檔已保留」，不自己清空。
struct TranscriptListView: View {
    @State private var transcripts: [Transcript] = []
    @State private var unreadableCount = 0
    @State private var loadFailed = false

    var body: some View {
        List {
            if unreadableCount > 0 {
                unreadableBanner
            }
            ForEach(transcripts) { transcript in
                NavigationLink {
                    TranscriptDetailView(transcript: transcript)
                } label: {
                    row(transcript)
                }
                .listRowBackground(Token.Colors.rowBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .overlay {
            if transcripts.isEmpty, unreadableCount == 0 {
                emptyState
            }
        }
        .navigationTitle("文字稿")
        .task { reload() }
    }

    private func row(_ transcript: Transcript) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text(Self.subtitle(for: transcript))
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
            Text(transcript.displayText)
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineLimit(2)
        }
    }

    private var unreadableBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: Token.Space.s) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Token.Colors.danger)
                .accessibilityHidden(true)
            Text("有 \(unreadableCount) 篇歷史讀不到，原檔已保留。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textPrimary)
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    private var emptyState: some View {
        Text(loadFailed ? "文字稿讀取失敗。" : "還沒有文字稿。回首頁按中間的玉米，說一段話。")
            .font(Token.Fonts.secondary)
            .foregroundStyle(Token.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Token.Space.xl)
    }

    /// 「10 月 31 日 14:32・3 分 48 秒」（線框詳情頁的副標）。
    static func subtitle(for transcript: Transcript) -> String {
        let date = transcript.createdAt.formatted(date: .abbreviated, time: .shortened)
        return date + "・" + RecordingSheetView.formatSpoken(transcript.durationSeconds)
    }

    private func reload() {
        do {
            let result = try TranscriptStore().loadAll()
            transcripts = result.transcripts
            unreadableCount = result.unreadableCount
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}
