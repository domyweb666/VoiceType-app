import SwiftUI

/// 鎖定畫面那一條。底與字用系統的，跟著淺深色走；domy 的顏色只用淺深同值的玉米黃那一組，不會看不見。
struct RecordingLockScreenView: View {
    /// 系統只給 160 點高，超過會被切；字級放到這裡為止。
    private static let largestTypeSize = DynamicTypeSize.accessibility2
    private static let smallestScale = 0.6

    let state: RecordingActivityAttributes.ContentState
    let display: RecordingActivityDisplay

    var body: some View {
        HStack(spacing: DomyTokens.Space.s3) {
            Image(systemName: display.symbol)
                .font(DomyTokens.TypeScale.title3.font)
                .foregroundStyle(DomyTheme.gold.onBright)
                .frame(width: DomyTokens.Size.iconButton, height: DomyTokens.Size.iconButton)
                .background(DomyTheme.gold.bright, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DomyTokens.Space.s1) {
                Text(display.title)
                    .font(DomyTokens.TypeScale.title3.font)
                    .foregroundStyle(.primary)
                    .accessibilityLabel(display.spokenTitle)
                if let hint = display.hint {
                    Text(hint)
                        .font(DomyTokens.TypeScale.subheadline.font)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(Self.smallestScale)
            Spacer(minLength: DomyTokens.Space.s2)
            RecordingActivityTimer(state: state, display: display)
                .font(DomyTokens.TypeScale.title1.font)
                .foregroundStyle(.primary)
        }
        .padding(DomyTokens.Space.s4)
        .dynamicTypeSize(...Self.largestTypeSize)
        .accessibilityElement(children: .combine)
    }
}
