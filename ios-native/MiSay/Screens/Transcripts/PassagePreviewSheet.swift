import SwiftUI

/// W4 改一段：上面原本、下面改好的，按「換上」才換進文字稿；按「不要」什麼都不動。
/// 送出與換上在 `DraftEditor`，這張頁只顯示。
struct PassagePreviewSheet: View {
    /// 一次改一段的請求。位置記第幾個字：等的時候字可能被改過，舊的 String.Index 不能再用。
    struct Request: Identifiable {
        let id = UUID()
        let kind: PassageRewriteKind
        let original: String
        let offset: Int
        var result: String?
        var failure: String?
    }

    let request: Request
    let onApply: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Token.Space.l) {
                    passage("原本", text: request.original, color: Token.Colors.textSecondary)
                    if let result = request.result {
                        passage("改好的", text: result, color: Token.Colors.textPrimary)
                    } else if let failure = request.failure {
                        Text(failure)
                            .font(Token.Fonts.secondary)
                            .foregroundStyle(Token.Colors.danger)
                    } else {
                        ProgressView("改寫中")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(Token.Space.l)
            }
            .background(Token.Colors.rowBackground)
            .safeAreaInset(edge: .bottom) { applyButton }
            .navigationTitle(request.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("不要", action: onDiscard)
                        .tint(Token.Colors.link)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
    }

    /// 這頁唯一的玉米黃；改好了才出現。
    @ViewBuilder
    private var applyButton: some View {
        if request.result != nil {
            Button("換上", action: onApply)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Token.Space.xl)
                .padding(.bottom, Token.Space.s)
        }
    }

    private func passage(_ title: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.s) {
            Text(title)
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
            Text(text)
                .font(Token.Fonts.body)
                .foregroundStyle(color)
                .lineSpacing(Token.Space.lineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
