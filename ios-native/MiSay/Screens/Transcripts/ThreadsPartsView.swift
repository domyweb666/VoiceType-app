import SwiftUI

/// 串文拆開來一篇一張卡：字數、超過上限的標出來、「複製第 N 篇」（2026-11-24）。
struct ThreadsPartsView: View {
    let parts: [ThreadsParts.Part]

    /// 剛複製的是第幾篇；停 2 秒，跟詳情頁的「已複製」一樣。
    @State private var copiedNumber: Int?
    @State private var copyCount = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Token.Space.m) {
                ForEach(parts) { card($0) }
            }
            .padding(.horizontal, Token.Space.screen)
            .padding(.vertical, Token.Space.m)
        }
        .background(Token.Colors.groupedBackground)
        .navigationTitle("逐篇複製")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(Token.Haptics.copied, trigger: copyCount)
    }

    /// 「320／500 字」；超過寫「520／500 字，多了 20 字」。
    static func countText(for part: ThreadsParts.Part) -> String {
        let limit = ThreadsParts.characterLimit
        let count = "\(part.characterCount.formatted())／\(limit.formatted()) 字"
        return part.overflow == 0 ? count : count + "，多了 \(part.overflow.formatted()) 字"
    }

    private func card(_ part: ThreadsParts.Part) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.s) {
            countLabel(part)
            Text(part.text)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineSpacing(Token.Space.lineSpacing)
                .textSelection(.enabled)
            Button {
                copy(part)
            } label: {
                if copiedNumber == part.number {
                    Label("已複製", systemImage: "checkmark")
                } else {
                    Label("複製第 \(part.number) 篇", systemImage: "doc.on.doc")
                }
            }
            .buttonStyle(TextButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Token.Space.l)
        .background(
            Token.Colors.rowBackground,
            in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow, style: .continuous)
        )
    }

    /// 超過的有圖示、有字，不只靠顏色（使用規則第 4 條）。
    private func countLabel(_ part: ThreadsParts.Part) -> some View {
        HStack(spacing: Token.Space.xs) {
            if part.overflow > 0 {
                Image(systemName: "exclamationmark.circle.fill")
                    .accessibilityHidden(true)
            }
            Text(Self.countText(for: part))
        }
        .font(Token.Fonts.footnote)
        .foregroundStyle(part.overflow > 0 ? Token.Colors.danger : Token.Colors.textSecondary)
    }

    private func copy(_ part: ThreadsParts.Part) {
        DraftPasteboard.copy(part.markdown)
        copiedNumber = part.number
        copyCount += 1
        let count = copyCount
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if copyCount == count {
                copiedNumber = nil
            }
        }
    }
}
