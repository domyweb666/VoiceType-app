import SwiftUI

/// 詳情頁工具列上方那一行（首次體驗檔詳情狀態表）：潤飾中、潤飾失敗、存不進去、沒有文字、已複製。
/// 一次只顯示一種，優先順序在 `kind(...)`；長相交給共用的 `StatusStrip`（2026-11-07 統一風格）。
struct TranscriptStatusStrip: View {
    enum Kind: Equatable {
        case hidden
        case polishing
        /// `hadDraft` 是 false 時是「整理這篇」失敗：本來就沒有文字稿，不能說「沒有被改動」。
        case polishFailed(hadDraft: Bool)
        case saveFailed
        case empty
        case copied
    }

    let kind: Kind
    let onCancel: () -> Void
    let onRetry: () -> Void

    /// 一次只講一件事，照這個順序：正在潤飾 > 潤飾失敗 > 存不進去 > 沒有文字 > 剛複製。
    static func kind(
        isPolishing: Bool,
        polishFailed: Bool,
        hasDraft: Bool,
        saveFailed: Bool,
        isEmpty: Bool = false,
        showsCopied: Bool = false
    ) -> Kind {
        if isPolishing {
            return .polishing
        }
        if polishFailed {
            return .polishFailed(hadDraft: hasDraft)
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
                message: "重新潤飾中…舊的文字稿還在",
                actionTitle: "取消",
                action: onCancel
            )
        case let .polishFailed(hadDraft):
            StatusStrip(
                glyph: .failed,
                message: hadDraft ? "重新潤飾沒有成功，文字稿沒有被改動。" : "整理沒有成功，口語稿還在。",
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
