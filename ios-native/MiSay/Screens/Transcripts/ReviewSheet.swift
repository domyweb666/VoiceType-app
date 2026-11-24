import SwiftUI

/// 「請 AI 看整篇」那張頁（2026-11-24）：上面三種，按一種就送；下面是回來的意見，最近問的在前。
/// 送出在詳情頁（`TranscriptDetailView+Review`），這張頁收起來照樣看完；意見當純文字顯示（安全標準五）。
struct ReviewSheet: View {
    /// 這次打開這篇問到的意見。每種只留最近一次。
    struct Session {
        private(set) var results: [ReviewResult] = []
        var runningKind: ReviewKind?
        var failure: String?
        var task: Task<Void, Never>?

        mutating func add(_ result: ReviewResult) {
            results.removeAll { $0.kind == result.kind }
            results.insert(result, at: 0)
        }
    }

    let session: Session
    /// 現在的文字稿：引文照它找位置。
    let text: String
    let currentTitle: String?
    let onReview: (ReviewKind) -> Void
    let onCancel: () -> Void
    let onPickTitle: (String) -> Void
    let onJump: (Range<Int>) -> Void

    @Environment(\.dismiss) var dismiss

    static let costNote = "只給意見，不會改你的稿。每按一次，會用到一點 OpenAI 的費用。"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ReviewKind.allCases) { kindRow($0) }
                } footer: {
                    footer
                }
                .listRowBackground(Token.Colors.rowBackground)

                ForEach(session.results) { resultSection($0) }
                    .listRowBackground(Token.Colors.rowBackground)
            }
            .font(Token.Fonts.body)
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .navigationTitle("請 AI 看整篇")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if session.runningKind != nil {
            ToolbarItem(placement: .cancellationAction) {
                Button("停止看稿", action: onCancel)
                    .tint(Token.Colors.link)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("完成") { dismiss() }
                .tint(Token.Colors.link)
        }
    }

    /// 正在看的那種右邊轉圈，其他種先按不下去（一次只看一種）。
    private func kindRow(_ kind: ReviewKind) -> some View {
        let isRunning = session.runningKind == kind
        return Button {
            onReview(kind)
        } label: {
            HStack(spacing: Token.Space.m) {
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text(kind.title)
                        .foregroundStyle(Token.Colors.textPrimary)
                    Text(isRunning ? "看稿中，長的稿子要等一下" : kind.summary)
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                if isRunning {
                    ProgressView()
                }
            }
        }
        .disabled(session.runningKind != nil)
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
