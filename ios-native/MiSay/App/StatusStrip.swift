import SwiftUI

/// 狀態條（使用規則第 13 條）：圖示＋字＋右邊一個金色動作字，一次只講一件事。
/// 潤飾中、失敗、已複製、已刪除、刪不掉都用它；浮在清單上時加一點陰影。
struct StatusStrip: View {
    enum Glyph {
        case working
        case failed
        case done
        case note
    }

    let glyph: Glyph
    let message: String
    var actionTitle: String?
    var action: () -> Void = {}
    var isFloating = false

    var body: some View {
        HStack(spacing: Token.Space.s) {
            glyphView
            Text(message)
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textPrimary)
            Spacer(minLength: Token.Space.s)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(Token.Fonts.secondary.weight(.medium))
                    .tint(Token.Colors.link)
            }
        }
        .padding(.horizontal, Token.Space.l)
        .padding(.vertical, Token.Space.m)
        .background(
            Token.Colors.rowBackground,
            in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow)
        )
        .shadow(
            color: Token.Colors.shadow.opacity(shadowOpacity),
            radius: Token.Elevation.stripShadowRadius,
            y: Token.Elevation.stripShadowY
        )
    }

    private var shadowOpacity: Double {
        isFloating ? Token.Elevation.stripShadowOpacity : 0
    }

    /// 圖示＋文字一起出現，顏色不單獨承載意義（使用規則第 4 條）。
    @ViewBuilder
    private var glyphView: some View {
        switch glyph {
        case .working:
            ProgressView()
                .tint(Token.Colors.link)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Token.Colors.danger)
                .accessibilityHidden(true)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Token.Colors.link)
                .accessibilityHidden(true)
        case .note:
            EmptyView()
        }
    }
}
