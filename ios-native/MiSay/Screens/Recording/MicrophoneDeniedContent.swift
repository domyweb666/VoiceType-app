import SwiftUI

/// 片 C2：文案照首次體驗檔權限時刻表；「打開『設定』」直接開系統設定的米說頁。
/// 2026-11-07 統一風格：圖示圓、主要按鈕玉米黃膠囊、「先不要」金色文字鈕。
/// 2026-11-27 B 版：說明靠左放在上半部，兩顆鈕收進底部托盤。
struct MicrophoneDeniedContent: View {
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        RecordingTrayLayout {
            IconCircle(systemName: "mic.slash.fill")
            Text("芋音聽不到你的聲音")
                .font(Token.Fonts.largeTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            Text("麥克風權限是關的。到『設定』打開芋音的麥克風，回來就能錄。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
        } tray: {
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
