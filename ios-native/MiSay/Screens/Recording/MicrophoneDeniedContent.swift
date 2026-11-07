import SwiftUI

/// 片 C2：文案照首次體驗檔權限時刻表；「打開『設定』」直接開系統設定的米說頁。
/// 2026-11-07 統一風格：圖示圓、主要按鈕玉米黃膠囊、「先不要」金色文字鈕。
struct MicrophoneDeniedContent: View {
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Token.Space.m) {
            IconCircle(systemName: "mic.slash.fill")
            Text("米說聽不到你的聲音")
                .font(Token.Fonts.sectionTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            Text("麥克風權限是關的。到『設定』打開米說的麥克風，回來就能錄。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Spacer(minLength: Token.Space.s)
            Button("打開『設定』") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
                onClose()
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("先不要") {
                onClose()
            }
            .buttonStyle(TextButtonStyle())
        }
    }
}
