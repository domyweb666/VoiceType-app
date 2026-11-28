import SwiftUI

/// R-C 托盤裡三種意見各自的樣子（設計稿 R-C3～R-C5）。
/// 開頭、卡在哪一次講一條，左右翻；卡在哪找得到的才給「到編輯頁改這句」，找不到的排在最後、只能看。
extension ReviewSheet {
    @ViewBuilder
    func resultContent(_ result: ReviewResult) -> some View {
        switch result {
        case let .titles(titles):
            titleResult(titles)
        case let .opening(opening):
            openingResult(opening)
        case .stuck:
            stuckResult(locatedPoints)
        }
    }

    /// 結果上面那一行：講這份是什麼，右邊可以再看一次（會再花一次錢、蓋掉這份）。
    private func resultHeader(_ label: String, kind: ReviewKind) -> some View {
        HStack(spacing: Token.Space.s) {
            Text(label)
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
            Spacer(minLength: Token.Space.s)
            Button {
                send(kind)
            } label: {
                Label("再看一次", systemImage: "arrow.clockwise")
            }
            .buttonStyle(TextButtonStyle())
            .accessibilityHint(Self.costNote)
        }
    }

    // MARK: 下標題

    /// 候選不會重複（`ReviewResult` 去過），拿字當 id。
    private func titleResult(_ titles: [String]) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            resultHeader("點一個設成標題，上面會跟著換", kind: .titles)
            ForEach(Array(titles.enumerated()), id: \.element) { index, title in
                if index > 0 {
                    separator
                }
                titleRow(title)
            }
        }
    }

    private func titleRow(_ title: String) -> some View {
        let isCurrent = title == currentTitle
        return Button {
            pickTitle(title)
        } label: {
            HStack(spacing: Token.Space.m) {
                Text(title)
                    .font(isCurrent ? Token.Fonts.rowTitle : Token.Fonts.body)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Token.Space.s)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(Token.Fonts.rowTitle)
                        .foregroundStyle(Token.Colors.link)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Token.Space.m)
            .frame(minHeight: Token.Shape.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    // MARK: 開頭

    private func openingResult(_ opening: OpeningReview) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.m) {
            resultHeader("開頭大約前 \(ReviewKind.openingCharacters) 字，框在上面", kind: .opening)
            Text(opening.summary)
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textPrimary)
                .textSelection(.enabled)
            separator
            if opening.points.isEmpty {
                statusLine(.done, "開頭夠力，AI 沒有要你改的地方。")
            } else {
                let index = clampedIndex(count: opening.points.count)
                pager(index: index, count: opening.points.count, unit: "個")
                openingPoint(opening.points[index])
            }
        }
    }

    private func openingPoint(_ point: OpeningPoint) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.s) {
            Text(point.problem)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
            VStack(alignment: .leading, spacing: Token.Space.xs) {
                Text("可以試")
                    .font(Token.Fonts.footnote.weight(.semibold))
                    .foregroundStyle(Token.Colors.link)
                Text(point.direction)
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
            .padding(Token.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Token.Colors.accentTint,
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusField, style: .continuous)
            )
        }
        .textSelection(.enabled)
    }

    // MARK: 卡在哪

    private func stuckResult(_ points: [LocatedStuckPoint]) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.m) {
            if points.isEmpty {
                resultHeader(ReviewKind.stuck.title, kind: .stuck)
                statusLine(.done, "AI 沒有看到會卡住的地方。")
            } else {
                resultHeader("\(points.count) 處，卡得最嚴重的在前面", kind: .stuck)
                let index = clampedIndex(count: points.count)
                pager(index: index, count: points.count, unit: "處")
                stuckPoint(points[index])
                if let missing = missingNote(points, current: index) {
                    note(missing)
                }
            }
        }
    }

    /// 找得到的那句已經塗在上面，托盤只講為什麼；找不到的把引文抄出來，不然看不到是哪句。
    @ViewBuilder
    private func stuckPoint(_ located: LocatedStuckPoint) -> some View {
        if let range = located.range {
            Text(located.point.reason)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .textSelection(.enabled)
            Button {
                onJump(range)
                dismiss()
            } label: {
                Label("到編輯頁改這句", systemImage: "arrow.up.right")
            }
            .buttonStyle(PrimaryButtonStyle())
        } else {
            Text("「\(located.point.quote)」")
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textSecondary)
                .padding(Token.Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Token.Colors.sunkenBackground,
                    in: RoundedRectangle(cornerRadius: Token.Shape.radiusField, style: .continuous)
                )
            Text(located.point.reason)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
            note("現在的稿子裡找不到這句，可能已經改掉了，所以沒辦法跳過去。")
        }
    }

    /// 翻到找得到的那幾處時，先講後面有幾處找不到，免得以為 AI 少給了（設計稿 R-C5 最下面那行）。
    private func missingNote(_ points: [LocatedStuckPoint], current: Int) -> String? {
        guard points[current].range != nil else {
            return nil
        }
        let numbers = points.indices.filter { points[$0].range == nil }.map { String($0 + 1) }
        guard !numbers.isEmpty else {
            return nil
        }
        return "第 \(numbers.joined(separator: "、")) 處在現在的稿子裡找不到，翻到最後會看到。"
    }

    // MARK: 左右翻

    private func clampedIndex(count: Int) -> Int {
        min(max(pointIndex, 0), count - 1)
    }

    private func pager(index: Int, count: Int, unit: String) -> some View {
        HStack(spacing: Token.Space.s) {
            pageButton("chevron.left", label: "上一\(unit)", isEnabled: index > 0) {
                pointIndex = index - 1
            }
            Text("第 \(index + 1) \(unit)，共 \(count) \(unit)")
                .font(Token.Fonts.secondary.weight(.semibold))
                .foregroundStyle(Token.Colors.textPrimary)
                .frame(maxWidth: .infinity)
            pageButton("chevron.right", label: "下一\(unit)", isEnabled: index < count - 1) {
                pointIndex = index + 1
            }
        }
    }

    private func pageButton(
        _ symbol: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Token.Fonts.secondary.weight(.semibold))
                .foregroundStyle(isEnabled ? Token.Colors.link : Token.Colors.textTertiary)
                .frame(width: Token.Shape.minTap, height: Token.Shape.minTap)
                .background(
                    isEnabled ? Token.Colors.accentSoft : Token.Colors.sunkenBackground,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}
