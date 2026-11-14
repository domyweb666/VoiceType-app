import SwiftUI

/// 錄音大鈕的長相（使用規則第 14 條），照 domy-design 的 HeroButton 待機狀態：
/// 淡金外環、玉米黃圓盤、深色麥克風，第 2 級陰影。只管長相；按下縮放與開面板在 `HomeView`。
/// 2026-11-14 米選照 domy：拿掉 11/07 快門式那圈上亮下暗，外環從金色半透明改淡金。
struct RecordButtonLabel: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Token.Colors.actionRing, lineWidth: Token.Shape.recordRing)
            Circle()
                .fill(Token.Colors.actionFill)
                .frame(width: Token.Shape.recordDisc, height: Token.Shape.recordDisc)
                .shadow(
                    color: Token.Colors.shadow.opacity(Token.Elevation.recordShadowOpacity),
                    radius: Token.Elevation.recordShadowRadius,
                    y: Token.Elevation.recordShadowY
                )
            Image(systemName: "mic.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Token.Colors.actionInk)
                .frame(width: Token.Shape.recordGlyph, height: Token.Shape.recordGlyph)
                .accessibilityHidden(true)
        }
        .frame(width: Token.Shape.recordTap, height: Token.Shape.recordTap)
    }
}
