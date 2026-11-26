import SwiftUI

/// W1「改寫成其他格式」那張頁（2026-11-09）：上面五種格式，按一種就改寫；下面是改寫好的。
/// Y5：改寫好的是自己的一篇，點了收起這張頁、打開那篇去改（列在 `RewritesSheet+Finished`）。
/// 送出與存檔在詳情頁（`TranscriptDetailView+Rewrite`），這張頁收起來改寫照樣做完、存好。
/// W2：最上面一格補充要求，可以不填，只用在這次改寫。
struct RewritesSheet: View {
    /// 從這篇改寫來的，新的在前。
    let derived: [Transcript]
    /// 以前存在這篇底下的，舊的在前。
    let rewrites: [TranscriptRewrite]
    let rewritingKind: RewriteKind?
    let failure: String?
    @Binding var instruction: String
    let onRewrite: (RewriteKind, String?) -> Void
    let onCancel: () -> Void
    let onOpen: (Transcript) -> Void
    let onDeleteDerived: (Transcript) -> Void
    let onEdit: (TranscriptRewrite) -> String?
    let onDelete: (TranscriptRewrite) -> Void

    @Environment(\.dismiss) private var dismiss
    @State var deleteCount = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("例如：保留我舉的例子、用大白話", text: $instruction, axis: .vertical)
                        .lineLimit(1 ... 4)
                } header: {
                    Text("補充要求（可以不填）")
                } footer: {
                    instructionFooter
                }
                .listRowBackground(Token.Colors.rowBackground)

                Section {
                    ForEach(RewriteKind.allCases) { kindRow($0) }
                } header: {
                    Text("改寫成")
                } footer: {
                    footer
                }
                .listRowBackground(Token.Colors.rowBackground)

                if !derived.isEmpty || !rewrites.isEmpty {
                    finishedSection
                }
            }
            .font(Token.Fonts.body)
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .sensoryFeedbackIfEnabled(Token.Haptics.deleted, trigger: deleteCount)
            .navigationTitle("改寫成…")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TranscriptRewrite.self) { rewrite in
                RewriteTextView(
                    rewrite: rewrite,
                    canEdit: rewritingKind == nil,
                    onEdit: onEdit
                )
            }
            .toolbar { toolbarContent }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if rewritingKind != nil {
            ToolbarItem(placement: .cancellationAction) {
                Button("停止改寫", action: onCancel)
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
            onRewrite(kind, RewriteKind.cleanedInstruction(instruction))
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
        .disabled(rewritingKind != nil || isInstructionTooLong)
    }

    private var isInstructionTooLong: Bool {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines).count > RewriteKind
            .maxInstructionCharacters
    }

    /// 太長時講現在幾個字，五種先按不下去；平常講清楚只管這一次。
    private var instructionFooter: some View {
        Text(Self
            .instructionNote(characters: instruction.trimmingCharacters(in: .whitespacesAndNewlines)
                .count))
            .font(Token.Fonts.footnote)
            .foregroundStyle(isInstructionTooLong ? Token.Colors.danger : Token.Colors
                .textSecondary)
    }

    static func instructionNote(characters: Int) -> String {
        guard characters > RewriteKind.maxInstructionCharacters else {
            return "只用在這次改寫，你的潤飾方式不會變。"
        }
        return "補充要求最多 \(RewriteKind.maxInstructionCharacters) 字，現在 \(characters) 字。"
    }

    /// 失敗講原因（紅字只給失敗）；平常講清楚文字稿不會動、每次都會花一點錢。
    private var footer: some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            if let failure {
                Text(failure)
                    .foregroundStyle(Token.Colors.danger)
            }
            Text("改寫會另外存成一篇，你的文字稿不會動。每改寫一次，會用到一點 OpenAI 的費用。")
                .foregroundStyle(Token.Colors.textSecondary)
        }
        .font(Token.Fonts.footnote)
    }
}
