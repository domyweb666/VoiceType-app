import SwiftUI

/// 詳情頁底部三顆：複製、重新潤飾、分享，圖示在上字在下，全部金色，沒有主角（使用規則第 2 條）。
/// 分享走系統 `ShareLink`（E5：給檔案才有「儲存到檔案」）。
struct TranscriptToolbar: View {
    let canCopy: Bool
    let showsRepolish: Bool
    let canRepolish: Bool
    let shareItem: TranscriptTextFile
    let sharePreview: String
    let onCopy: () -> Void
    let onRepolish: () -> Void

    var body: some View {
        HStack(spacing: Token.Space.s) {
            Button(action: onCopy) {
                label("複製", systemImage: "doc.on.doc")
            }
            .disabled(!canCopy)
            if showsRepolish {
                Button(action: onRepolish) {
                    label("重新潤飾", systemImage: "sparkles")
                }
                .disabled(!canRepolish)
            }
            ShareLink(item: shareItem, preview: SharePreview(sharePreview)) {
                label("分享", systemImage: "square.and.arrow.up")
            }
            .disabled(!canCopy)
        }
        .buttonStyle(ToolbarItemStyle())
        .tint(Token.Colors.link)
        .frame(minHeight: Token.Shape.primaryTap)
    }

    private func label(_ title: String, systemImage: String) -> some View {
        VStack(spacing: Token.Space.xs) {
            Image(systemName: systemImage)
                .font(Token.Fonts.icon)
            Text(title)
                .font(Token.Fonts.footnote)
        }
        .frame(maxWidth: .infinity, minHeight: Token.Shape.minTap)
    }
}

/// 三顆平分寬度、金色、按下變淡、停用變更淡；`ShareLink` 也吃這個樣式。
private struct ToolbarItemStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let opacity = Token.Motion.buttonOpacity(
            isEnabled: isEnabled,
            isPressed: configuration.isPressed
        )
        return configuration.label
            .foregroundStyle(Token.Colors.link)
            .opacity(opacity)
    }
}
