import SwiftUI

/// 詳情頁底下那一行（首次體驗檔詳情狀態表）：整理中、整理失敗、存不進去、沒有文字、已複製。
/// 一次只顯示一種，優先順序在 `kind(...)`；長相交給共用的 `StatusStrip`（2026-11-07 統一風格）。
/// 2026-11-08 重新潤飾拿掉了，整理只發生在還沒有文字稿的篇，失敗那句只剩一種。
struct TranscriptStatusStrip: View {
    enum Kind: Equatable {
        case hidden
        case polishing
        case polishFailed
        case saveFailed
        case empty
        case copied
    }

    let kind: Kind
    let onCancel: () -> Void
    let onRetry: () -> Void

    /// 一次只講一件事，照這個順序：正在整理 > 整理失敗 > 存不進去 > 沒有文字 > 剛複製。
    static func kind(
        isPolishing: Bool,
        polishFailed: Bool,
        saveFailed: Bool,
        isEmpty: Bool = false,
        showsCopied: Bool = false
    ) -> Kind {
        if isPolishing {
            return .polishing
        }
        if polishFailed {
            return .polishFailed
        }
        if saveFailed {
            return .saveFailed
        }
        if isEmpty {
            return .empty
        }
        return showsCopied ? .copied : .hidden
    }

    var body: some View {
        switch kind {
        case .hidden:
            EmptyView()
        case .polishing:
            StatusStrip(
                glyph: .working,
                message: "整理中…口語稿還在",
                actionTitle: "取消",
                action: onCancel
            )
        case .polishFailed:
            StatusStrip(
                glyph: .failed,
                message: "整理沒有成功，口語稿還在。",
                actionTitle: "再試一次",
                action: onRetry
            )
        case .saveFailed:
            StatusStrip(glyph: .failed, message: "改的字沒存進去，字還在這裡。再改一個字會再存一次。")
        case .empty:
            StatusStrip(glyph: .note, message: "沒有文字可以複製")
        case .copied:
            StatusStrip(glyph: .done, message: "已複製")
        }
    }
}
