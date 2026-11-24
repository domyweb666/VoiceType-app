import SwiftUI

/// 2026-11-24 以前存下來的一份改寫：唯讀、可以選字，右上複製、分享。
/// 要改就「拿來編輯」，存成自己的一篇；存好之後外面會收起這張頁、打開那一篇。
struct RewriteTextView: View {
    let rewrite: TranscriptRewrite
    /// 改寫中不給：打開那一篇會離開詳情頁，改寫就停了。
    let canEdit: Bool
    /// 沒成回要講的話。
    let onEdit: (TranscriptRewrite) -> String?

    @State private var editFailure: String?
    @State private var showsParts = false
    @State private var copyCount = 0
    /// 複製後圖示換成勾 2 秒，跟詳情頁的「已複製」一樣停 2 秒。
    @State private var showsCopied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Token.Space.m) {
                // W2：這份當時多打了什麼要求，看得到才知道為什麼長這樣。
                if let instruction = rewrite.instruction {
                    Text("補充要求：" + instruction)
                        .font(Token.Fonts.footnote)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                Text(rewrite.text)
                    .font(Token.Fonts.body)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .lineSpacing(Token.Space.lineSpacing)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Token.Space.l)
        }
        .background(Token.Colors.rowBackground)
        .safeAreaInset(edge: .bottom) { editBar }
        .navigationTitle(RewriteKind.title(forStored: rewrite.kind))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsParts) {
            ThreadsPartsView(parts: ThreadsParts.split(rewrite.text))
        }
        .toolbar { toolbarContent }
        .tint(Token.Colors.link)
        .sensoryFeedback(Token.Haptics.copied, trigger: copyCount)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            ShareLink(item: rewrite.text) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享")
            Button(action: copy) {
                Image(systemName: showsCopied ? "checkmark" : "doc.on.doc")
            }
            .accessibilityLabel(showsCopied ? "已複製" : "複製全文")
        }
    }

    private var editBar: some View {
        VStack(spacing: Token.Space.s) {
            if RewriteKind.isThreads(stored: rewrite.kind) {
                Button("逐篇複製") { showsParts = true }
                    .buttonStyle(TextButtonStyle())
            }
            Text(editFailure ?? "會存成自己的一篇，能改字、能匯出。")
                .font(Token.Fonts.footnote)
                .foregroundStyle(
                    editFailure == nil ? Token.Colors.textSecondary : Token.Colors.danger
                )
            Button("拿來編輯") {
                editFailure = onEdit(rewrite)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canEdit)
        }
        .padding(.horizontal, Token.Space.xl)
        .padding(.bottom, Token.Space.s)
        .background(Token.Colors.groupedBackground)
    }

    private func copy() {
        DraftPasteboard.copy(rewrite.text)
        copyCount += 1
        showsCopied = true
        let count = copyCount
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if copyCount == count {
                showsCopied = false
            }
        }
    }
}
