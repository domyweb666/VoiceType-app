import SwiftUI

/// 快門式錄音鈕的長相（使用規則第 14 條）：金環、有厚度的玉米黃圓盤、實心麥克風。
/// 只管長相；按下縮放與開面板在 `HomeView`。
/// 2026-11-09 米：玉米麥克風圖不好看，換回 11/07 畫布那版；酒紅圓盤是為了襯玉米圖才改的，一起換回來。
struct RecordButtonLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Token.Colors.actionRing, lineWidth: Token.Shape.recordRing)
            disc
            Image(systemName: "mic.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Token.Colors.actionInk)
                .frame(width: Token.Shape.recordGlyph, height: Token.Shape.recordGlyph)
                .accessibilityHidden(true)
        }
        .frame(width: Token.Shape.recordTap, height: Token.Shape.recordTap)
    }

    /// 上亮下暗是一圈從亮到暗的描邊，不是漸層底。
    private var disc: some View {
        Circle()
            .fill(Token.Colors.actionFill)
            .overlay {
                Circle()
                    .strokeBorder(rim, lineWidth: Token.Elevation.recordRimWidth)
            }
            .frame(width: Token.Shape.recordDisc, height: Token.Shape.recordDisc)
            .shadow(
                color: Token.Colors.shadow.opacity(shadowOpacity),
                radius: Token.Elevation.recordShadowRadius,
                y: Token.Elevation.recordShadowY
            )
    }

    private var rim: LinearGradient {
        LinearGradient(
            colors: [
                Token.Colors.highlight.opacity(Token.Elevation.recordHighlightOpacity),
                .clear,
                Token.Colors.actionInk.opacity(Token.Elevation.recordRimOpacity),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shadowOpacity: Double {
        colorScheme == .dark
            ? Token.Elevation.recordShadowOpacityDark
            : Token.Elevation.recordShadowOpacity
    }
}
