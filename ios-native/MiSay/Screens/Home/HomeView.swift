import SwiftUI

/// 首頁：米 2026-10-31 鎖定的骨架，正中央超大錄音鈕，其他全搬走。
/// 片 A2 只做殼：鈕按了沒動作（錄音是組塊 C），待轉錄 0 個時整列不出現（所以這裡沒畫）。
struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Spacer()
            recordButton
            // 下半的 Spacer 讓鈕停在正中央；文案掛在它上緣，不把鈕往上擠。
            // Spacer 在 VStack 裡寬度是 0，要先撐到整寬，overlay 的文字才有地方換行。
            Spacer()
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) { firstTimeHint }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.Colors.groupedBackground)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink("文字稿") { TranscriptListView() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("更多")
            }
        }
    }

    @ViewBuilder
    private var recordButton: some View {
        let button = Button {
            // 片 A2 刻意沒有動作；錄音在組塊 C 接上
        } label: {
            Text("說")
                .font(Token.Fonts.largeTitle)
                .foregroundStyle(Token.Colors.actionInk)
                .frame(width: Token.Shape.recordTap, height: Token.Shape.recordTap)
                .background(Token.Colors.actionFill, in: Circle())
        }
        .accessibilityLabel("開始錄音")

        // 減少動態時不縮放，用系統預設的按壓回饋（變淡）。代號檔寫的「底色加深」還沒有數值，
        // 等設計代號補了再換，不在這裡發明數字。
        if reduceMotion {
            button
        } else {
            button.buttonStyle(RecordButtonStyle())
        }
    }

    private var firstTimeHint: some View {
        VStack(spacing: Token.Space.s) {
            Text("按中間的玉米，說一段話")
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            Text("說完會變成可以直接貼上的文字，自動幫你複製。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, Token.Space.xl)
        .padding(.horizontal, Token.Space.xl)
    }
}

/// 按下去縮一下（2-4 回饋）。只在沒開「減少動態」時用。
private struct RecordButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Token.Motion.recordPressScale : 1)
            .animation(Token.Motion.recordPress(false), value: configuration.isPressed)
    }
}
