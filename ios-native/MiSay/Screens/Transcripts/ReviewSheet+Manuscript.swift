import SwiftUI

/// R-C 上半部：唯讀的稿子。只能看、能選字複製，不能改；改字回編輯頁。
/// 卡在哪：找得到的句子塗淡金、前面放編號，托盤正在講的那處塗玉米黃。開頭：AI 看的那幾段框起來。
/// 下標題：點了的候選已經是這篇的標題時，標題框起來寫「標題換成」。
extension ReviewSheet {
    var manuscript: some View {
        let paragraphs = ReviewMarks.paragraphs(of: text, marks: marks)
        let opening = isOpeningFramed ? paragraphs.filter(isInOpening) : []
        let rest = paragraphs.dropFirst(opening.count)
        return VStack(alignment: .leading, spacing: Token.Space.m) {
            Text("唯讀，要改字請到編輯頁")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
                .id(ManuscriptAnchor.top)
            titleView
            if !opening.isEmpty {
                openingFrame(opening)
            }
            ForEach(rest) { paragraphView($0) }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Token.Space.xl)
        .padding(.top, Token.Space.m)
        .padding(.bottom, Token.Space.xl)
        .opacity(session.runningKind == nil ? 1 : Token.Motion.reviewRunningOpacity)
    }

    /// 卡在哪翻到哪一處，就捲到那一句；開頭、下標題捲回最上面。看稿中不動。
    var scrollAnchor: ManuscriptAnchor? {
        guard session.runningKind == nil, let kind = shownKind else {
            return nil
        }
        guard kind == .stuck else {
            return .top
        }
        let paragraphs = ReviewMarks.paragraphs(of: text, marks: [])
        guard let range = currentPoint?.range,
              let id = ReviewMarks.paragraphID(containing: range.lowerBound, in: paragraphs)
        else {
            return nil
        }
        return .paragraph(id)
    }

    var currentPoint: LocatedStuckPoint? {
        let points = locatedPoints
        return points.indices.contains(pointIndex) ? points[pointIndex] : nil
    }

    /// 只有托盤停在「卡在哪」才塗；找不到位置的那幾處沒得塗，只在托盤裡看。
    private var marks: [ReviewMarks.Mark] {
        guard shownKind == .stuck, session.runningKind == nil else {
            return []
        }
        return locatedPoints.enumerated().compactMap { index, located in
            located.range.map {
                ReviewMarks.Mark(number: index + 1, range: $0, isCurrent: index == pointIndex)
            }
        }
    }

    private var isOpeningFramed: Bool {
        guard shownKind == .opening, session.runningKind == nil else {
            return false
        }
        return result(for: .opening) != nil
    }

    /// 開頭那段從前 `openingCharacters` 個字裡開始的都框進去，跟提示詞說的「大約前 300 字」一樣。
    private func isInOpening(_ paragraph: ReviewMarks.Paragraph) -> Bool {
        paragraph.range.lowerBound < ReviewKind.openingCharacters
    }

    private var isTitlePicked: Bool {
        guard shownKind == .titles, case let .titles(titles)? = result(for: .titles) else {
            return false
        }
        return titles.contains { $0 == currentTitle }
    }

    @ViewBuilder
    private var titleView: some View {
        if let title = currentTitle, !title.isEmpty {
            if isTitlePicked {
                dashedBox(
                    VStack(alignment: .leading, spacing: Token.Space.xs) {
                        Text("標題換成")
                            .font(Token.Fonts.footnote.weight(.semibold))
                            .foregroundStyle(Token.Colors.link)
                        titleText(title)
                    }
                )
            } else {
                titleText(title)
            }
        }
    }

    private func titleText(_ title: String) -> some View {
        Text(title)
            .font(Token.Fonts.reviewTitle)
            .foregroundStyle(Token.Colors.textPrimary)
    }

    /// 「AI 看的開頭」牌子騎在框的上緣。框往左右伸出去了，右緣本來就在框裡面一點，牌子不用再內縮。
    private func openingFrame(_ paragraphs: [ReviewMarks.Paragraph]) -> some View {
        dashedBox(
            VStack(alignment: .leading, spacing: Token.Space.m) {
                ForEach(paragraphs) { paragraphView($0) }
            }
            .padding(.top, Token.Space.xs)
        )
        .overlay(alignment: .topTrailing) {
            Text("AI 看的開頭")
                .font(Token.Fonts.footnote.weight(.semibold))
                .foregroundStyle(Token.Colors.onAccent)
                .padding(.horizontal, Token.Space.s)
                .background(Token.Colors.accent, in: Capsule())
                .alignmentGuide(.top) { $0[VerticalAlignment.center] }
        }
    }

    /// 虛線框往左右各伸出一點，框裡的字才跟外面的段落對齊（設計稿 R-C3、R-C4）。
    private func dashedBox(_ content: some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: Token.Shape.radiusField, style: .continuous)
        let dash = StrokeStyle(lineWidth: Token.Shape.hairline, dash: Token.Shape.reviewFrameDash)
        return content
            .padding(Token.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Token.Colors.accentTint, in: shape)
            .overlay { shape.strokeBorder(Token.Colors.accent, style: dash) }
            .padding(.horizontal, -Token.Space.s)
    }

    private func paragraphView(_ paragraph: ReviewMarks.Paragraph) -> some View {
        Text(attributed(paragraph.segments))
            .font(Token.Fonts.body)
            .lineSpacing(Token.Space.lineSpacing)
            .foregroundStyle(Token.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(ManuscriptAnchor.paragraph(paragraph.id))
    }

    private func attributed(_ segments: [ReviewMarks.Segment]) -> AttributedString {
        var string = AttributedString()
        for segment in segments {
            switch segment {
            case let .text(value, highlight):
                string += piece(value, highlight)
            case let .badge(number, isCurrent):
                string += badge(number, isCurrent: isCurrent)
            }
        }
        return string
    }

    /// 塗色只是幫忙找，意思靠前面的編號（顏色不單獨承載意義，使用規則第 4 條）。
    private func piece(_ value: String, _ highlight: ReviewMarks.Highlight) -> AttributedString {
        var run = AttributedString(value)
        switch highlight {
        case .plain:
            break
        case .marked:
            run.backgroundColor = Token.Colors.accentSoft
        case .current:
            run.backgroundColor = Token.Colors.reviewMarkCurrent
            run.foregroundColor = Token.Colors.reviewMarkCurrentInk
        }
        return run
    }

    /// 編號前後各一個細空格，塗了底色看起來才像一顆小牌子。
    private func badge(_ number: Int, isCurrent: Bool) -> AttributedString {
        var run = AttributedString("\u{2009}\(number)\u{2009}")
        run.font = Token.Fonts.footnote.weight(.bold)
        run.foregroundColor = isCurrent ? Token.Colors.onAccent : Token.Colors.link
        run.backgroundColor = isCurrent ? Token.Colors.accent : Token.Colors.accentSoft
        return run
    }
}
