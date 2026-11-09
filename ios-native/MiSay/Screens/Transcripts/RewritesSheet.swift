import SwiftUI

/// W1「改寫成其他格式」那張頁（2026-11-09）：上面五種格式，按一種就改寫；下面是改寫好的幾份，點進去看、複製、分享。
/// 送出與存檔在詳情頁（`TranscriptDetailView+Rewrite`），這張頁收起來改寫照樣做完、存好。
struct RewritesSheet: View {
    let rewrites: [TranscriptRewrite]
    let rewritingKind: RewriteKind?
    let failure: String?
    let onRewrite: (RewriteKind) -> Void
    let onCancel: () -> Void
    let onDelete: (TranscriptRewrite) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var path: [TranscriptRewrite] = []
    /// 這張頁上按的那次改寫好了，直接推進去看；從別處來的變動（刪一份）不推。
    @State private var isWaitingForResult = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(RewriteKind.allCases) { kindRow($0) }
                } header: {
                    Text("改寫成")
                } footer: {
                    footer
                }
                .listRowBackground(Token.Colors.rowBackground)

                if !rewrites.isEmpty {
                    Section("改寫好的") {
                        ForEach(rewrites.reversed()) { rewrite in
                            NavigationLink(value: rewrite) { rewriteRow(rewrite) }
                        }
                        .onDelete { offsets in
                            let newestFirst = Array(rewrites.reversed())
                            offsets.map { newestFirst[$0] }.forEach(onDelete)
                        }
                    }
                    .listRowBackground(Token.Colors.rowBackground)
                }
            }
            .font(Token.Fonts.body)
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .navigationTitle("改寫成其他格式")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TranscriptRewrite.self) { RewriteTextView(rewrite: $0) }
            .toolbar { toolbarContent }
            .onChange(of: rewrites.last?.id) { _, newest in
                guard isWaitingForResult, newest != nil, let rewrite = rewrites.last else {
                    return
                }
                isWaitingForResult = false
                path = [rewrite]
            }
            .onChange(of: rewritingKind) { _, kind in
                // 失敗或被停掉：不會有新的一份，別等了。
                if kind == nil, failure != nil {
                    isWaitingForResult = false
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if rewritingKind != nil {
            ToolbarItem(placement: .cancellationAction) {
                Button("停止改寫") {
                    isWaitingForResult = false
                    onCancel()
                }
                .tint(Token.Colors.link)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("完成") { dismiss() }
                .tint(Token.Colors.link)
        }
    }

    /// 改寫中那一種右邊轉圈，其他種先按不下去（一次只改寫一種）。
    private func kindRow(_ kind: RewriteKind) -> some View {
        Button {
            isWaitingForResult = true
            onRewrite(kind)
        } label: {
            HStack(spacing: Token.Space.m) {
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text(kind.title)
                        .foregroundStyle(Token.Colors.textPrimary)
                    Text(rewritingKind == kind ? "改寫中，長的稿子要一兩分鐘" : kind.summary)
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                if rewritingKind == kind {
                    ProgressView()
                }
            }
        }
        .disabled(rewritingKind != nil)
    }

    private func rewriteRow(_ rewrite: TranscriptRewrite) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text(RewriteKind.title(forStored: rewrite.kind))
                .foregroundStyle(Token.Colors.textPrimary)
            Text(rewrite.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
        }
    }

    /// 失敗講原因（紅字只給失敗）；平常講清楚文字稿不會動、每次都會花一點錢。
    private var footer: some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            if let failure {
                Text(failure)
                    .foregroundStyle(Token.Colors.danger)
            }
            Text("改寫是另外存一份，你的文字稿不會動。每改寫一次，會用到一點 OpenAI 的費用。")
                .foregroundStyle(Token.Colors.textSecondary)
        }
        .font(Token.Fonts.footnote)
    }
}

/// 改寫好的一份：唯讀、可以選字，右上複製、分享。要改字就複製出去改，這份不給編輯（W5 再說）。
private struct RewriteTextView: View {
    let rewrite: TranscriptRewrite
    @State private var copyCount = 0
    /// 複製後圖示換成勾 2 秒，跟詳情頁的「已複製」一樣停 2 秒。
    @State private var showsCopied = false

    var body: some View {
        ScrollView {
            Text(rewrite.text)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineSpacing(Token.Space.lineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Token.Space.l)
        }
        .background(Token.Colors.rowBackground)
        .navigationTitle(RewriteKind.title(forStored: rewrite.kind))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
        .tint(Token.Colors.link)
        .sensoryFeedback(Token.Haptics.copied, trigger: copyCount)
    }

    private func copy() {
        UIPasteboard.general.string = rewrite.text
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
