import SwiftUI

/// E3 刪除與復原。2026-11-24 起刪掉的進垃圾桶，30 天後才真的刪；5 秒內照舊能直接復原。
extension TranscriptListView {
    /// 底部「已刪除・復原」（詞彙表）。5 秒內按復原，那篇回到清單原位（照時間排，位置自然回來）。
    @ViewBuilder
    var undoBanner: some View {
        if pendingDeletion != nil {
            StatusStrip(
                glyph: .done,
                message: "已刪除",
                actionTitle: "復原",
                action: undoDeletion,
                isFloating: true
            )
            .padding(.horizontal, Token.Space.screen)
            .padding(.bottom, Token.Space.s)
        } else if deleteFailed {
            // 清單有東西時空狀態那句不會出現，刪不掉要在這裡講，不然那篇像是自己跑回來。
            StatusStrip(glyph: .failed, message: "沒刪掉，這篇還在。再刪一次看看。")
                .padding(.horizontal, Token.Space.screen)
                .padding(.bottom, Token.Space.s)
        }
    }

    /// 清單最底下的垃圾桶。選取、搜尋時不出現；清單空了由空狀態那顆鈕帶去。
    @ViewBuilder
    func trashRow(hasVisible: Bool) -> some View {
        let hasRows = hasVisible || unreadableCount > 0
        if trashCount > 0, hasRows, !isSelecting, query.isEmpty {
            Section {
                Button(action: openTrash) {
                    Label(Self.trashTitle(count: trashCount), systemImage: "trash")
                        .font(Token.Fonts.body)
                }
                .tint(Token.Colors.link)
            }
            .listRowBackground(Token.Colors.rowBackground)
        }
    }

    static func trashTitle(count: Int) -> String {
        "垃圾桶（\(count) 篇）"
    }

    /// 還在等 5 秒的那篇先搬進去，打開垃圾桶才看得到它。
    func openTrash() {
        commitDeletionNow()
        showsTrash = true
    }

    /// 數不到就當沒有：入口少出現一次，裡面的篇不受影響。
    func reloadTrashCount() {
        let trashedIDs = (try? TranscriptStore().trashedIDs()) ?? []
        trashCount = trashedIDs.subtracting(transcripts.map(\.id)).count
    }

    /// 先從畫面拿掉、5 秒後才真的搬；期間按「復原」就放回去。
    func softDelete(_ transcript: Transcript) {
        commitDeletionNow()
        deleteFailed = false
        pendingDeletion = transcript
        deleteCount += 1
        deletionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.undoWindowSeconds))
            guard !Task.isCancelled else {
                return
            }
            commitDeletionNow()
        }
    }

    func undoDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        pendingDeletion = nil
    }

    func commitDeletionNow() {
        deletionTask?.cancel()
        deletionTask = nil
        guard let doomed = pendingDeletion else {
            return
        }
        pendingDeletion = nil
        do {
            try Self.discard(id: doomed.id)
            transcripts.removeAll { $0.id == doomed.id }
            reloadTrashCount()
        } catch {
            // 搬不進去就留著：它還在清單裡，並且說出來，比默默消失誠實。
            deleteFailed = true
        }
    }

    /// 看存檔裡最新的那份：一個字都沒寫的新文稿直接刪，其他的進垃圾桶。
    static func discard(id: UUID) throws {
        let store = TranscriptStore()
        if let latest = try store.load(id: id), latest.isBlankDraft {
            try store.delete(id: id)
        } else {
            try store.moveToTrash(id: id)
        }
    }
}
