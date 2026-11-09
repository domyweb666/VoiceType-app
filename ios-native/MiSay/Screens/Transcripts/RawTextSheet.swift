import SwiftUI

/// 詳情頁「⋯ → 看口語稿／看 AI 改了什麼」升起的那張頁（2026-11-09 從詳情檔搬出來，加 W3）。
/// 上面分段切「口語稿」與「AI 改了什麼」；兩邊都唯讀、可以選字複製，看完拉下去。
struct RawTextSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case raw = "口語稿"
        case diff = "AI 改了什麼"

        var id: Self {
            self
        }
    }

    let transcript: Transcript
    @State private var mode: Mode
    @State private var diff: PolishDiff?
    @Environment(\.dismiss) private var dismiss

    init(transcript: Transcript, startsWithDiff: Bool) {
        self.transcript = transcript
        _mode = State(initialValue: startsWithDiff ? .diff : .raw)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Token.Space.l) {
                    Picker("顯示", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch mode {
                    case .raw:
                        bodyText(Text(transcript.rawText))
                    case .diff:
                        diffContent
                    }
                }
                .padding(Token.Space.l)
            }
            .background(Token.Colors.rowBackground)
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .tint(Token.Colors.link)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
        .task { await compare() }
    }

    /// 比的是 AI 剛整理出來、還沒被人改過的那份；v0.1.9 以前整理的篇沒存那份，只能拿現在的文字稿比。
    var polishedForCompare: String? {
        transcript.originalDraft ?? transcript.draftText
    }

    /// 一小時的稿子要比幾萬個字，放到背景算，畫面先轉圈。
    private func compare() async {
        guard diff == nil, let polished = polishedForCompare,
              !PolishDiff.isTooLong(raw: transcript.rawText, polished: polished)
        else {
            return
        }
        let raw = transcript.rawText
        diff = await Task.detached(priority: .userInitiated) {
            PolishDiff(from: raw, to: polished)
        }.value
    }

    @ViewBuilder
    private var diffContent: some View {
        if let polished = polishedForCompare,
           PolishDiff.isTooLong(raw: transcript.rawText, polished: polished)
        {
            note("這篇太長，手機比不動。可以切到「口語稿」自己對照。")
        } else if polishedForCompare == nil {
            note("這篇還沒整理成文字稿，沒有東西可以比。")
        } else if let diff {
            VStack(alignment: .leading, spacing: Token.Space.s) {
                note(Self.summary(diff))
                if transcript.originalDraft == nil {
                    note("這篇是比較早整理的，沒存 AI 剛整理好的那份，比的是你改過之後的字，你自己改的也會算進去。")
                }
            }
            bodyText(Text(Self.attributed(diff)))
        } else {
            ProgressView("比對中")
                .frame(maxWidth: .infinity)
        }
    }

    /// 字跟樣子一起講（使用規則第 4 條）：刪掉的畫線、加上的底下有線，不只靠顏色分。
    static func summary(_ diff: PolishDiff) -> String {
        guard diff.removedCount > 0 || diff.addedCount > 0 else {
            return "AI 一個字都沒改。"
        }
        return "跟口語稿比，AI 刪了 \(diff.removedCount.formatted()) 字、加了 \(diff.addedCount.formatted()) 字"
            + "（空白不算）。紅色畫線的是刪掉的，底下有線、有底色的是加上的。"
    }

    /// 刪掉的：紅字加刪除線（紅色只給刪除，使用規則第 11 條）；加上的：凹槽底色加底線。
    static func attributed(_ diff: PolishDiff) -> AttributedString {
        var result = AttributedString()
        for run in diff.runs {
            var part = AttributedString(run.text)
            switch run.kind {
            case .same:
                part.foregroundColor = Token.Colors.textPrimary
            case .removed:
                part.foregroundColor = Token.Colors.danger
                part.strikethroughStyle = Text.LineStyle.single
            case .added:
                part.foregroundColor = Token.Colors.textPrimary
                part.backgroundColor = Token.Colors.sunkenBackground
                part.underlineStyle = Text.LineStyle.single
            }
            result += part
        }
        return result
    }

    private func bodyText(_ text: Text) -> some View {
        text
            .font(Token.Fonts.body)
            .foregroundStyle(Token.Colors.textPrimary)
            .lineSpacing(Token.Space.lineSpacing)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func note(_ message: String) -> some View {
        Text(message)
            .font(Token.Fonts.footnote)
            .foregroundStyle(Token.Colors.textSecondary)
    }
}
