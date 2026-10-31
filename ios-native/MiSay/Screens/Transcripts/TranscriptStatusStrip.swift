import SwiftUI

/// 詳情頁工具列上方那一行（首次體驗檔詳情狀態表）：潤飾中、潤飾失敗、存不進去、沒有文字、已複製。
/// 一次只顯示一種，優先順序在 `kind(...)`。
struct TranscriptStatusStrip: View {
    enum Kind: Equatable {
        case hidden
        case polishing
        /// `hadDraft` 是 false 時是「整理這篇」失敗：本來就沒有文字稿，不能說「沒有被改動」。
        case polishFailed(hadDraft: Bool)
        case saveFailed
        case empty
        case copied
    }

    let kind: Kind
    let onCancel: () -> Void
    let onRetry: () -> Void

    /// 一次只講一件事，照這個順序：正在潤飾 > 潤飾失敗 > 存不進去 > 沒有文字 > 剛複製。
    static func kind(
        isPolishing: Bool,
        polishFailed: Bool,
        hasDraft: Bool,
        saveFailed: Bool,
        isEmpty: Bool,
        showsCopied: Bool
    ) -> Kind {
        if isPolishing {
            return .polishing
        }
        if polishFailed {
            return .polishFailed(hadDraft: hasDraft)
        }
        if saveFailed {
            return .saveFailed
        }
        if isEmpty {
            return .empty
        }
        return showsCopied ? .copied : .hidden
    }

    var body: some View {
        switch kind {
        case .hidden:
            EmptyView()
        case .polishing:
            HStack(spacing: Token.Space.s) {
                ProgressView()
                Text("重新潤飾中…舊的文字稿還在")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                Spacer()
                Button("取消", action: onCancel)
                    .font(Token.Fonts.footnote)
                    .tint(Token.Colors.link)
            }
            .modifier(StripBackground())
        case let .polishFailed(hadDraft):
            failure(
                hadDraft ? "重新潤飾沒有成功，文字稿沒有被改動。" : "整理沒有成功，口語稿還在。",
                showsRetry: true
            )
        case .saveFailed:
            failure("改的字沒存進去，字還在這裡。再改一個字會再存一次。", showsRetry: false)
        case .empty:
            note("沒有文字可以複製")
        case .copied:
            note("已複製")
        }
    }

    /// 圖示＋文字一起出現，顏色不單獨承載意義（使用規則第 4 條）。
    private func failure(_ message: String, showsRetry: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Token.Space.s) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Token.Colors.danger)
                .accessibilityHidden(true)
            Text(message)
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textPrimary)
            Spacer()
            if showsRetry {
                Button("再試一次", action: onRetry)
                    .font(Token.Fonts.footnote)
                    .tint(Token.Colors.link)
            }
        }
        .modifier(StripBackground())
    }

    private func note(_ message: String) -> some View {
        Text(message)
            .font(Token.Fonts.footnote)
            .foregroundStyle(Token.Colors.textSecondary)
            .padding(.vertical, Token.Space.s)
    }
}

private struct StripBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Token.Space.l)
            .padding(.vertical, Token.Space.s)
            .background(Token.Colors.rowBackground)
    }
}
