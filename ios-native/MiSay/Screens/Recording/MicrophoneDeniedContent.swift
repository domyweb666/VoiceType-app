import SwiftUI

/// 片 C2：文案照首次體驗檔權限時刻表；「打開『設定』」直接開系統設定的米說頁。
struct MicrophoneDeniedContent: View {
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Token.Space.m) {
            Text("米說聽不到你的聲音")
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            Text("麥克風權限是關的。到『設定』打開米說的麥克風，回來就能錄。")
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
                onClose()
            } label: {
                Text("打開『設定』")
                    .font(Token.Fonts.rowTitle)
                    .frame(maxWidth: .infinity, minHeight: Token.Shape.primaryTap)
            }
            .buttonStyle(.borderedProminent)
            .tint(Token.Colors.link)
            Button("先不要") {
                onClose()
            }
            .font(Token.Fonts.body)
            .tint(Token.Colors.link)
        }
    }
}
