import SwiftUI

/// 錄音畫面 B 版「上面看、下面按」的骨架（2026-11-27 米選定）：
/// 上半部給人看（計時、聲波、狀態），能按的全收進底部一塊白色托盤，拇指按得到。
/// 首頁待機、錄音中、被打斷、整理中、完成、各種失敗都套這一個，鈕才會一直在同一個位置。
/// 上半部太高（字放大、小手機、半頁面板）時自己捲，托盤固定在底下；托盤放在原生分頁列上方，靠安全區讓開。
struct RecordingTrayLayout<Stage: View, Tray: View>: View {
    @ViewBuilder let stage: Stage
    @ViewBuilder let tray: Tray

    var body: some View {
        VStack(spacing: Token.Space.m) {
            ScrollView {
                VStack(alignment: .leading, spacing: Token.Space.l) {
                    stage
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Token.Space.m)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: Token.Space.s) {
                tray
            }
            .frame(maxWidth: .infinity)
            .padding(Token.Space.l)
            .background(
                Token.Colors.rowBackground,
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusTray, style: .continuous)
            )
            .shadow(
                color: Token.Colors.shadow.opacity(Token.Elevation.trayShadowOpacity),
                radius: Token.Elevation.trayShadowRadius,
                y: Token.Elevation.trayShadowY
            )
        }
        .padding(.horizontal, Token.Space.screen)
        .padding(.bottom, Token.Space.l)
    }
}
