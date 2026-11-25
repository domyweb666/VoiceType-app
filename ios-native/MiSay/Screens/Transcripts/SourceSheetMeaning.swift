import SwiftUI

/// 「AI 改了什麼」最上面的「可能改了意思」（片 J2）：一列一處，寫種類跟口語稿那附近的原話。
/// 錄音還能播的篇，點一列就從那附近聽；不能播的照列，不能點。
struct SourceSheetMeaning: View {
    /// nil 是沒有比（接著錄過的篇）。
    let findings: [MeaningCheck.Finding]?
    let timeline: [TimelineSpan]
    /// 從錄音的第幾秒附近聽；不能播的篇是 nil。
    let onListen: ((Double) -> Void)?

    static let nothingFound = "沒看到可能改了意思的地方。"
        + "只看否定字（不、沒、別、未、無）、大部分的數字和詞彙表的名字，不保證全部抓到。"
    static let explanation = "這些字在文字稿對應的地方不見了，或換掉了。是不是真的改了意思，要你看一下。"
    static let notCompared = "這篇是好幾段錄音接起來的，口語稿跟文字稿的順序可能對不上，這裡沒有比。"

    var body: some View {
        VStack(alignment: .leading, spacing: Token.Space.m) {
            Text("可能改了意思")
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(Self.summary(count: findings?.count))
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
            LazyVStack(alignment: .leading, spacing: Token.Space.m) {
                ForEach(findings ?? []) { finding in
                    row(finding)
                }
            }
        }
        .padding(Token.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Token.Colors.sunkenBackground,
            in: RoundedRectangle(cornerRadius: Token.Shape.radiusField, style: .continuous)
        )
    }

    static func summary(count: Int?) -> String {
        guard let count else {
            return notCompared
        }
        return count < 1 ? nothingFound : "\(count.formatted()) 處。" + explanation
    }

    static func listenLabel(_ seconds: Double) -> String {
        "聽 \(RecordingSheetView.formatElapsed(seconds)) 附近"
    }

    @ViewBuilder
    private func row(_ finding: MeaningCheck.Finding) -> some View {
        if let onListen {
            let seconds = SpokenTimeline.seconds(ofCharacter: finding.offset, in: timeline)
            Button {
                onListen(seconds)
            } label: {
                rowText(finding, listenLabel: Self.listenLabel(seconds))
            }
            .buttonStyle(.plain)
            .accessibilityHint("從錄音這附近開始播")
        } else {
            rowText(finding, listenLabel: nil)
        }
    }

    private func rowText(_ finding: MeaningCheck.Finding, listenLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            HStack {
                Text(finding.kind.rawValue)
                    .foregroundStyle(Token.Colors.textSecondary)
                Spacer()
                if let listenLabel {
                    Text(listenLabel)
                        .foregroundStyle(Token.Colors.link)
                }
            }
            .font(Token.Fonts.footnote)
            Text(Self.excerpt(finding))
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: Token.Shape.minTap, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// 那個字粗體加底線，不只靠顏色（使用規則第 4 條）。
    static func excerpt(_ finding: MeaningCheck.Finding) -> AttributedString {
        var word = AttributedString(finding.word)
        word.inlinePresentationIntent = .stronglyEmphasized
        word.underlineStyle = Text.LineStyle.single
        return AttributedString(finding.before) + word + AttributedString(finding.after)
    }
}
