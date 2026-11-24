import SwiftUI

/// 「⋯ → 版本紀錄」（2026-11-15）：AI 剛整理好的那一版，和你每次打開來改之前的樣子。
/// 點一版看全文，按「換回這一版」整篇換回去；換之前現在的樣子也會先留一版，所以換錯了回得來。
struct VersionsSheet: View {
    let current: String
    /// AI 剛整理好、還沒被改過的那份；自己打的新文稿與舊的篇沒有。
    let aiDraft: String?
    let versions: [DraftVersion]
    let onRestore: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    static let previewLength = 40
    static let note = "每次打開來改，改之前的樣子會留一版；連著改很久，每十分鐘再留一版。"
        + "最近 \(Transcript.maxVersions) 版都留著，"
        + "更早的每天留最後一版，最多 \(Transcript.maxDailyVersions) 天。"

    var body: some View {
        NavigationStack {
            List {
                if let aiDraft, aiDraft != current {
                    Section {
                        row(title: "AI 剛整理好的那一版", text: aiDraft)
                    }
                }
                if !versions.isEmpty {
                    Section {
                        ForEach(versions.reversed()) { version in
                            row(title: Self.title(for: version), text: version.text)
                        }
                    } header: {
                        Text("你改之前的樣子")
                    } footer: {
                        Text(Self.note)
                            .font(Token.Fonts.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .overlay { emptyNote }
            .navigationTitle("版本紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    /// 「11月15日 下午3:20・1,234 字」
    static func title(for version: DraftVersion) -> String {
        let time = version.savedAt.formatted(date: .abbreviated, time: .shortened)
        return time + "・" + TranscriptDetailView.progress(
            count: DictationStats.countCharacters(version.text),
            goal: nil
        )
    }

    /// 列上面那兩行預覽：開頭的幾個字，去掉記號，換行當空白。
    static func preview(_ text: String) -> String {
        PlainTextExport.opening(of: text, limit: previewLength)
            .replacingOccurrences(of: "\n", with: " ")
    }

    private var hasNothing: Bool {
        versions.isEmpty && (aiDraft == nil || aiDraft == current)
    }

    @ViewBuilder
    private var emptyNote: some View {
        if hasNothing {
            ContentUnavailableView {
                Label("還沒有舊的版本", systemImage: "clock.arrow.circlepath")
            } description: {
                Text("改過字之後，改之前的樣子會留在這裡。")
            }
        }
    }

    private func row(title: String, text: String) -> some View {
        NavigationLink {
            VersionPreview(title: title, text: text) {
                onRestore(text)
            }
        } label: {
            VStack(alignment: .leading, spacing: Token.Space.xs) {
                Text(title)
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                Text(Self.preview(text))
                    .font(Token.Fonts.body)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .lineLimit(2)
            }
        }
        .listRowBackground(Token.Colors.rowBackground)
    }
}

/// 一版的全文，只能看、能選字複製；下面一顆「換回這一版」。
private struct VersionPreview: View {
    let title: String
    let text: String
    let onRestore: () -> Void

    var body: some View {
        ScrollView {
            Text(text)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineSpacing(Token.Space.lineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Token.Space.screen)
                .padding(.top, Token.Space.s)
        }
        .background(Token.Colors.rowBackground)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Token.Space.s) {
                Text("現在的樣子會先留一版，換錯了回得來。")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                Button("換回這一版", action: onRestore)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, Token.Space.xl)
            .padding(.bottom, Token.Space.s)
            .background(Token.Colors.groupedBackground)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
