import SwiftUI

/// 快門式錄音鈕的長相（使用規則第 14 條）：金環、有厚度的酒紅圓盤、玉米麥克風圖。
/// 只管長相；按下縮放與開面板在 `HomeView`。
/// 2026-11-08 米：中間換成玉米麥克風圖，圓盤從玉米黃換成 App icon 的酒紅，不然玉米跟底分不開。
struct RecordButtonLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Token.Colors.actionRing, lineWidth: Token.Shape.recordRing)
            disc
            Image("玉米麥克風")
                .resizable()
                .scaledToFit()
                .frame(height: Token.Shape.recordGlyph)
                .accessibilityHidden(true)
        }
        .frame(width: Token.Shape.recordTap, height: Token.Shape.recordTap)
    }

    /// 上亮下暗是一圈從亮到暗的描邊，不是漸層底。
    private var disc: some View {
        Circle()
            .fill(Token.Colors.recordDiscFill)
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
