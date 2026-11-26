import SwiftUI

/// 文字稿清單 →「垃圾桶」（2026-11-24）：刪掉的篇放 30 天。每篇右邊一顆「⋯」，可以放回清單、立刻刪掉；
/// 左右滑是同一件事的捷徑。立刻刪掉一定先問，那篇留著的錄音跟著刪。
struct TrashView: View {
    /// 放回或刪掉之後叫：清單要重讀。
    let onChange: () -> Void

    @Environment(TranscriptionQueue.self) private var queue
    @State private var transcripts: [Transcript] = []
    @State private var loadFailed = false
    @State private var problem: String?
    @State private var doomed: Transcript?
    @State private var isConfirmingDelete = false
    @State private var deleteCount = 0

    static let note = "放 \(TranscriptStore.trashKeepDays) 天後自動刪掉，留著的錄音也一起刪。"
        + "垃圾桶裡的篇不會進備份，也不算在統計裡。"

    var body: some View {
        List {
            if !transcripts.isEmpty {
                Section {
                    ForEach(transcripts) { row($0) }
                } footer: {
                    Text(Self.note)
                        .font(Token.Fonts.footnote)
                }
                .listRowBackground(Token.Colors.rowBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .overlay { emptyNote }
        .safeAreaInset(edge: .bottom) {
            if let problem {
                StatusStrip(glyph: .failed, message: problem)
                    .padding(.horizontal, Token.Space.screen)
                    .padding(.bottom, Token.Space.s)
            }
        }
        .sensoryFeedbackIfEnabled(Token.Haptics.deleted, trigger: deleteCount)
        .navigationTitle("垃圾桶")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "真的刪掉這篇？",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible,
            presenting: doomed
        ) { transcript in
            Button("刪除這篇文字稿", role: .destructive) { deleteNow(transcript) }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("刪了救不回來，留著的錄音也會一起刪。")
        }
        .task { reload() }
    }

    /// 「還有 12 天」；到期還沒清的寫「今天會刪」。沒記時間的不會自動刪，不寫。
    static func daysLeftText(trashedAt: Date?, now: Date = .now) -> String? {
        guard let trashedAt else {
            return nil
        }
        let days = TranscriptStore.daysLeft(trashedAt: trashedAt, now: now)
        return days > 0 ? "還有 \(days) 天" : "今天會刪"
    }

    /// 寫過又全刪的那篇，正文是空的：拿最後留的那版認。
    static func rowText(for transcript: Transcript) -> String {
        if let title = TranscriptListView.rowTitle(of: transcript) {
            return title
        }
        let text = transcript.displayText
        guard Transcript.isBlank(text), let kept = transcript.versions?.last else {
            return PlainTextExport.opening(of: text)
        }
        return PlainTextExport.opening(of: kept.text)
    }

    private func row(_ transcript: Transcript) -> some View {
        HStack(spacing: Token.Space.s) {
            VStack(alignment: .leading, spacing: Token.Space.xs) {
                if let daysLeft = Self.daysLeftText(trashedAt: transcript.trashedAt) {
                    Text(daysLeft)
                        .font(Token.Fonts.footnote)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                Text(Self.rowText(for: transcript))
                    .font(Token.Fonts.body)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: Token.Space.s)
            Menu {
                Button("放回清單", systemImage: "arrow.uturn.backward") { restore(transcript) }
                Button("立刻刪除這篇…", systemImage: "trash", role: .destructive) {
                    confirmDelete(transcript)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(minWidth: Token.Shape.minTap, minHeight: Token.Shape.minTap)
                    .contentShape(Rectangle())
            }
            .tint(Token.Colors.link)
            .accessibilityLabel("更多")
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("放回清單") { restore(transcript) }
        }
        // 不標 destructive：系統會先把列收掉，可是還沒問過。
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("立刻刪除") { confirmDelete(transcript) }
                .tint(Token.Colors.danger)
        }
    }

    @ViewBuilder
    private var emptyNote: some View {
        if loadFailed {
            ContentUnavailableView {
                Label("垃圾桶一時讀不到", systemImage: "exclamationmark.triangle")
            } description: {
                Text("檔案都還在，等一下再打開這頁。")
            }
        } else if transcripts.isEmpty {
            ContentUnavailableView {
                Label("垃圾桶是空的", systemImage: "trash")
            } description: {
                Text("刪掉的文字稿會在這裡放 \(TranscriptStore.trashKeepDays) 天。")
            }
        }
    }

    private func reload() {
        do {
            transcripts = try TranscriptStore().loadTrash()
            loadFailed = false
        } catch {
            transcripts = []
            loadFailed = true
        }
    }

    private func restore(_ transcript: Transcript) {
        do {
            try TranscriptStore().restoreFromTrash(id: transcript.id)
            problem = nil
        } catch {
            problem = "沒放回去，這篇還在垃圾桶。再試一次。"
        }
        reload()
        onChange()
    }

    private func confirmDelete(_ transcript: Transcript) {
        doomed = transcript
        isConfirmingDelete = true
    }

    private func deleteNow(_ transcript: Transcript) {
        do {
            if try TranscriptStore().deleteFromTrash(id: transcript.id) {
                RetainedRecordings().remove(for: [transcript.id], excluding: queue.inFlight)
            }
            problem = nil
            deleteCount += 1
        } catch {
            problem = "沒刪掉，這篇還在垃圾桶。再試一次。"
        }
        reload()
        onChange()
    }
}
