import SwiftUI

/// 「這趟講了幾件事」那張頁（片 J3）：上面一列按了才送，中間是分出來的幾件事，勾了存成幾篇；
/// 最下面是以前拆出來的。送出與存檔在詳情頁（`TranscriptDetailView+Split`），這張頁收起來照樣分完。
struct SplitSheet: View {
    /// 這次打開這篇的結果，離開詳情頁就沒了。
    struct Session {
        private(set) var result: TopicSplit?
        /// 送出去那時候的字：之後改過字，存的還是那時候的。
        private(set) var source = ""
        private(set) var selectedIDs: Set<UUID> = []
        var savedIDs: Set<UUID> = []
        var isRunning = false
        var failure: String?
        var saveFailure: String?
        var task: Task<Void, Never>?

        /// 只有一件事就沒有東西要存。
        var unsavedTopics: [SplitTopic] {
            guard let topics = result?.topics, topics.count > 1 else {
                return []
            }
            return topics.filter { !savedIDs.contains($0.id) }
        }

        var chosenTopics: [SplitTopic] {
            unsavedTopics.filter { selectedIDs.contains($0.id) }
        }

        /// 先全部勾起來：沒按「存成」之前什麼都不會存。以前拆過的先不勾，免得重新分一次就存出重複的。
        mutating func show(
            _ newResult: TopicSplit,
            from text: String,
            hasEarlierPieces: Bool
        ) {
            result = newResult
            source = text
            selectedIDs = hasEarlierPieces ? [] : Set(newResult.topics.map(\.id))
            savedIDs = []
            saveFailure = nil
        }

        static func unsavedNote(count: Int) -> String {
            "有 \(count) 篇沒存成，手機空間可能不夠。再按一次只會存剩下的。"
        }

        /// 沒存成的留著，再按一次只會存它們。
        mutating func recordSave(of topics: [SplitTopic], failedIDs: Set<UUID>) {
            savedIDs.formUnion(topics.map(\.id).filter { !failedIDs.contains($0) })
            saveFailure = failedIDs.isEmpty ? nil : Self.unsavedNote(count: failedIDs.count)
        }

        mutating func toggle(_ id: UUID) {
            if selectedIDs.remove(id) == nil {
                selectedIDs.insert(id)
            }
        }
    }

    @Binding var session: Session
    /// 現在的文字稿，看送出去之後改過沒。
    let text: String
    /// 從這篇拆出來的，新的在前。
    let pieces: [Transcript]
    /// 打開別篇會離開詳情頁，正在分、正在改寫的就停了，所以先不給開。
    let canOpen: Bool
    let onStart: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void
    let onOpen: (Transcript) -> Void

    @Environment(\.dismiss) private var dismiss

    static let costNote = "AI 只分哪幾段是哪件事，存的字從你的文字稿照搬，這篇不會動。"
        + "每按一次，會用到一點 OpenAI 的費用。離開這篇，分好的結果不會留。"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    startRow
                } footer: {
                    footer
                }
                .listRowBackground(Token.Colors.rowBackground)

                if let result = session.result {
                    resultSection(result)
                }
                if !earlierPieces.isEmpty {
                    earlierSection
                }
            }
            .font(Token.Fonts.body)
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle("這趟講了幾件事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if session.isRunning {
            ToolbarItem(placement: .cancellationAction) {
                Button("停止", action: onCancel)
                    .tint(Token.Colors.link)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("完成") { dismiss() }
                .tint(Token.Colors.link)
        }
    }

    private var startRow: some View {
        Button(action: onStart) {
            HStack(spacing: Token.Space.m) {
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text(session.result == nil ? "分出這趟講的事" : "重新分一次")
                        .foregroundStyle(Token.Colors.textPrimary)
                    Text(session.isRunning ? "看稿中，長的稿子要等一下" : "分好之後，勾要存的，一件事存一篇")
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                if session.isRunning {
                    ProgressView()
                }
            }
        }
        .disabled(session.isRunning)
    }

    /// 失敗講原因（紅字只給失敗）；平常講清楚不動稿、每次都會花一點錢。
    private var footer: some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            if let failure = session.failure {
                Text(failure)
                    .foregroundStyle(Token.Colors.danger)
            }
            Text(Self.costNote)
                .foregroundStyle(Token.Colors.textSecondary)
        }
        .font(Token.Fonts.footnote)
    }
}
