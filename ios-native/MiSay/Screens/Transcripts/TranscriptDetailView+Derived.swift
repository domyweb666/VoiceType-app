import SwiftUI

/// 2026-11-24 Y5：改寫稿與原篇互相開、「⋯」裡改寫來的那幾項、串文逐篇複製。
extension TranscriptDetailView {
    /// 這一塊的狀態收在一起，主檔只放一個欄位。
    struct DerivedPages {
        /// 從這篇改寫來的，新的在前。
        private(set) var transcripts: [Transcript] = []
        /// 這頁上剛刪的：清單要等復原的時間過了才動存檔，那之前不能又列出來。
        private var deletedIDs: Set<UUID> = []
        /// 等改寫那張頁收好才開：邊收邊推頁，推的那一下可能不見。
        var pending: Transcript?
        /// 退回來的動畫還會畫到它，所以關掉時不清。
        var opened: Transcript?
        var showsOpened = false
        var showsThreadsParts = false
        /// 補充要求：改寫完不清掉，同一句常常想再換一種格式用。
        var instruction = ""

        mutating func refresh(sourceID: UUID, from stored: [Transcript]) {
            transcripts = Transcript.derived(of: sourceID, in: stored)
                .filter { !deletedIDs.contains($0.id) }
        }

        mutating func markDeleted(_ id: UUID) {
            deletedIDs.insert(id)
            transcripts.removeAll { $0.id == id }
        }

        func isDeleted(_ id: UUID) -> Bool {
            deletedIDs.contains(id)
        }
    }

    /// 「改寫：Threads 串文・gpt-6-luna」
    static func derivedNote(kind: String?, model: String?) -> String {
        let title = "改寫：" + RewriteKind.title(forStored: kind ?? "")
        return model.map { title + "・" + $0 } ?? title
    }

    /// 「⋯」最上面的說明，按不下去。
    var derivedNoteSection: some View {
        Section {
            Text(Self.derivedNote(kind: transcript.sourceKind, model: transcript.polishModel))
            if let instruction = transcript.sourceInstruction {
                Text("補充要求：" + instruction)
            }
        }
    }

    /// 改寫中先不給看原篇：離開這頁會停掉改寫。
    @ViewBuilder
    var openSourceMenuItem: some View {
        if transcript.isDerived {
            Button(action: openSource) {
                Label("看原篇", systemImage: "arrow.uturn.backward")
            }
            .disabled(rewritingKind != nil)
        }
    }

    @ViewBuilder
    var threadsPartsMenuItem: some View {
        if RewriteKind.isThreads(stored: transcript.sourceKind) {
            Button {
                derived.showsThreadsParts = true
            } label: {
                Label("逐篇複製", systemImage: "square.on.square")
            }
            .disabled(currentText.isEmpty)
        }
    }

    var threadsPartsSheet: some View {
        NavigationStack {
            ThreadsPartsView(parts: ThreadsParts.split(currentText))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { derived.showsThreadsParts = false }
                            .tint(Token.Colors.link)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
    }

    @ViewBuilder
    var relatedPage: some View {
        if let opened = derived.opened {
            TranscriptDetailView(
                transcript: opened,
                openedFrom: transcript.id,
                onDelete: deleteRelated,
                onLeave: onLeave
            )
            .id(opened.id)
        }
    }

    /// 改寫那張頁開著就先收，收好了（`onDismiss`）再開。
    func openRelated(_ target: Transcript) {
        derived.pending = target
        if showsRewrites {
            showsRewrites = false
        } else {
            openPendingRelated()
        }
    }

    /// 要開的就是點進來的那篇，退回去就好，不再疊一頁。
    func openPendingRelated() {
        guard let target = derived.pending else {
            return
        }
        derived.pending = nil
        if target.id == openedFrom {
            dismiss()
            return
        }
        flushAutosave()
        derived.opened = target
        derived.showsOpened = true
    }

    /// 刪除走清單那條路，這頁只記著別再列出來。
    func deleteRelated(_ target: Transcript) {
        derived.markDeleted(target.id)
        onDelete(target)
    }

    private func openSource() {
        do {
            let stored = try TranscriptStore().loadAll().transcripts
            let source = stored.first { $0.id == transcript.sourceID && $0.trashedAt == nil }
            if let source, !derived.isDeleted(source.id) {
                openRelated(source)
            } else {
                showNote("原篇已經刪掉了。")
            }
        } catch {
            showNote("原篇讀不到，再試一次。")
        }
    }
}
