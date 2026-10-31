import SwiftUI

/// 文字稿詳情（片 D7 先開一個只顯示文字稿的簡單頁；片 E1 才做口語稿對照、複製、工具列）。
struct TranscriptDetailView: View {
    let transcript: Transcript

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Token.Space.m) {
                Text(TranscriptListView.subtitle(for: transcript))
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                if transcript.draftText == nil {
                    Text("這篇還沒整理成文字稿。")
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                Text(transcript.displayText)
                    .font(Token.Fonts.body)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Token.Space.l)
        }
        .background(Token.Colors.groupedBackground)
        .navigationTitle("文字稿")
        .navigationBarTitleDisplayMode(.inline)
    }
}
