import SwiftUI

/// 「⋯ → 請 AI 看整篇」（2026-11-24 主力編輯器）：送出、收意見、把標題設給這篇、失敗翻成人話。
/// 三種各自按了才送，一次只看一種；只給意見，不改稿。意見不存，離開這頁就沒了。
extension TranscriptDetailView {
    /// 還沒有文字稿的篇沒有稿可以看。
    @ViewBuilder
    var reviewMenuItem: some View {
        if transcript.draftText != nil {
            Button {
                showsReview = true
            } label: {
                Label("請 AI 看整篇", systemImage: "text.magnifyingglass")
            }
            .disabled(isPolishing || currentText.isEmpty)
        }
    }

    var reviewSheet: some View {
        ReviewSheet(
            session: review,
            text: draftEdit,
            currentTitle: transcript.title,
            onReview: startReview,
            onCancel: cancelReview,
            onPickTitle: pickTitle,
            onJump: jump(to:)
        )
    }

    func startReview(_ kind: ReviewKind) {
        guard review.runningKind == nil, !isPolishing else {
            return
        }
        let source = draftEdit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            review.failure = "這篇沒有字可以看。"
            return
        }
        guard source.count <= RewriteKind.maxSourceCharacters else {
            review.failure = "這篇超過 3 萬字，太長了，沒有送出去。"
            return
        }
        review.failure = nil
        review.runningKind = kind
        review.task = Task { @MainActor in
            await runReview(source: source, kind: kind)
        }
    }

    /// 被停掉的那次不碰狀態：停掉後馬上按另一種，新的那次已經在用了。
    private func runReview(source: String, kind: ReviewKind) async {
        do {
            let result = try await Polisher().review(
                text: source,
                kind: kind,
                model: AppSettings.shared.polishModel,
                vocabulary: AppSettings.shared.vocabulary
            )
            guard !Task.isCancelled else {
                return
            }
            finishReview()
            review.add(result)
            if !showsReview {
                showNote("看好了：\(kind.title)，在「⋯ → 請 AI 看整篇」裡。")
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }
            finishReview()
            let message = Self.reviewFailureMessage(error)
            review.failure = message
            if !showsReview {
                showNote(message)
            }
        }
    }

    private func finishReview() {
        review.runningKind = nil
        review.task = nil
    }

    func cancelReview() {
        review.task?.cancel()
        finishReview()
    }

    private func pickTitle(_ title: String) {
        do {
            try updateStored {
                $0.title = title
                $0.updatedAt = Date()
            }
            review.failure = nil
        } catch {
            review.failure = "標題沒存進去，再試一次。"
        }
    }

    /// 網路與金鑰那些跟改寫同一套說法；沒有存檔這回事，所以其他的另外講。
    static func reviewFailureMessage(_ error: Error) -> String {
        switch error {
        case is OpenAIClient.Failure:
            rewriteFailureMessage(error)
        case Polisher.Failure.incomplete:
            "意見回到一半被截掉了，再按一次試試。"
        case is Polisher.Failure:
            "OpenAI 回來的意見看不懂，再按一次試試。"
        default:
            "沒有看成，再按一次試試。"
        }
    }
}
