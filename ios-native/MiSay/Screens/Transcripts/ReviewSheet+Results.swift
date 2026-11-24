import SwiftUI

/// 「請 AI 看整篇」三種意見各自的樣子。
extension ReviewSheet {
    @ViewBuilder
    func resultSection(_ result: ReviewResult) -> some View {
        switch result {
        case let .titles(titles):
            titleSection(titles)
        case let .opening(opening):
            openingSection(opening)
        case let .stuck(points):
            stuckSection(points)
        }
    }

    /// 候選不會重複（`ReviewResult` 去過），拿字當 id。
    private func titleSection(_ titles: [String]) -> some View {
        Section {
            ForEach(titles, id: \.self) { titleRow($0) }
        } header: {
            Text(ReviewKind.titles.title)
        } footer: {
            Text("點一個設成這篇的標題，再點別的會換掉。")
                .font(Token.Fonts.footnote)
        }
    }

    private func titleRow(_ title: String) -> some View {
        let isCurrent = title == currentTitle
        return Button {
            onPickTitle(title)
        } label: {
            HStack(spacing: Token.Space.m) {
                Text(title)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Token.Colors.link)
                }
            }
        }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func openingSection(_ opening: OpeningReview) -> some View {
        Section(ReviewKind.opening.title) {
            Text(opening.summary)
                .foregroundStyle(Token.Colors.textPrimary)
                .textSelection(.enabled)
            ForEach(Array(opening.points.enumerated()), id: \.offset) { _, point in
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text(point.problem)
                        .foregroundStyle(Token.Colors.textPrimary)
                    Text("可以試：" + point.direction)
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                .textSelection(.enabled)
            }
        }
    }

    private func stuckSection(_ points: [StuckPoint]) -> some View {
        Section(ReviewKind.stuck.title) {
            if points.isEmpty {
                Text("沒有看到會卡住的地方。")
                    .foregroundStyle(Token.Colors.textSecondary)
            }
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                stuckRow(point)
            }
        }
    }

    /// 在現在的稿子裡找得到那句才給點；找不到照樣看得到意見，只是點不了。
    @ViewBuilder
    private func stuckRow(_ point: StuckPoint) -> some View {
        if let range = ReviewResult.range(of: point.quote, in: text) {
            Button {
                onJump(range)
                dismiss()
            } label: {
                stuckText(point)
            }
            .accessibilityHint("跳到這一句")
        } else {
            VStack(alignment: .leading, spacing: Token.Space.xs) {
                stuckText(point)
                Text("現在的稿子裡找不到這句。")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
        }
    }

    private func stuckText(_ point: StuckPoint) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text("「\(point.quote)」")
                .foregroundStyle(Token.Colors.textPrimary)
            Text(point.reason)
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
        }
        .multilineTextAlignment(.leading)
    }
}
