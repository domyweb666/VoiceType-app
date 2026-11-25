import SwiftUI

/// 版本紀錄，與大綱那張頁裡會把整篇換掉的兩件事：全部取代、整段搬動（2026-11-15，寫長文第二批）。
/// 整篇被換掉之前都先把現在的樣子留一版；另外編輯框的復原也回得去。
extension TranscriptDetailView {
    /// 「版本紀錄…」；有留版就寫幾版。
    static func versionMenuTitle(count: Int) -> String {
        count == 0 ? "版本紀錄…" : "版本紀錄（\(count) 版）"
    }

    /// 「換了 3 處。」；取代成空的就是刪掉。
    static func replacedNote(count: Int, isDeleting: Bool) -> String {
        guard count > 0 else {
            return "沒有找到，什麼都沒換。"
        }
        return (isDeleting ? "刪了" : "換了") + " \(count) 處。打字時右上的彎箭頭可以回去。"
    }

    var versionsSheet: some View {
        VersionsSheet(
            current: draftEdit,
            aiDraft: transcript.originalDraft,
            aiDraftTitle: transcript.isSplit ? "剛拆出來的那一版" : "AI 剛整理好的那一版",
            versions: transcript.versions ?? [],
            onRestore: restoreVersion
        )
    }

    /// 這次打開還沒留過版，或離上次留版超過十分鐘。
    var isVersionDue: Bool {
        versionDueAt.map { Date() >= $0 } ?? true
    }

    func markVersionKept() {
        versionDueAt = Date().addingTimeInterval(Transcript.versionIntervalSeconds)
    }

    /// 整篇要被換掉之前叫：先把手上的字存好，再把它留一版。留不進去只講一聲，照樣往下做（復原還回得去）。
    func keepCurrentVersion() {
        do {
            try updateStored { $0.keepVersion() }
            markVersionKept()
        } catch {
            showNote("這一版沒留成，改壞了請用右上的彎箭頭回去。")
        }
    }

    func restoreVersion(_ text: String) {
        showsVersions = false
        keepCurrentVersion()
        draftEdit = text
    }

    func replaceAll(_ query: String, with replacement: String) {
        keepCurrentVersion()
        let result = DraftOutline.replacingAll(query, with: replacement, in: draftEdit)
        draftEdit = result.text
        showNote(Self.replacedNote(count: result.count, isDeleting: replacement.isEmpty))
    }

    /// 大綱裡拖一次存一次；同一次打開只在第一次拖之前留版，不然拖八次就把舊版擠光。
    func reorder(to text: String) {
        if isVersionDue {
            keepCurrentVersion()
        }
        draftEdit = text
    }
}
