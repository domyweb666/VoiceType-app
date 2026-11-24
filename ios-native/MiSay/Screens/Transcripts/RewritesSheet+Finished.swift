import SwiftUI

/// 改寫那張頁的下半「改寫好的」：自己一篇的在上（點了收起這張頁去改），以前存的在下（唯讀）。
extension RewritesSheet {
    var finishedSection: some View {
        Section("改寫好的") {
            ForEach(derived) { derivedRow($0) }
                .onDelete { offsets in
                    offsets.map { derived[$0] }.forEach(onDeleteDerived)
                    deleteCount += 1
                }
            ForEach(rewrites.reversed()) { rewrite in
                NavigationLink(value: rewrite) { rewriteRow(rewrite) }
            }
            .onDelete { offsets in
                let newestFirst = Array(rewrites.reversed())
                offsets.map { newestFirst[$0] }.forEach(onDelete)
                deleteCount += 1
            }
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    /// 有標題寫標題，沒有寫正文開頭。
    static func headline(for transcript: Transcript) -> String {
        MarkdownExport.title(of: transcript) ?? VersionsSheet.preview(transcript.displayText)
    }

    /// 「Threads 串文・2026年11月24日 下午3:20」
    static func subtitle(kind: String?, createdAt: Date) -> String {
        let time = createdAt.formatted(date: .abbreviated, time: .shortened)
        return RewriteKind.title(forStored: kind ?? "") + "・" + time
    }

    /// 改寫中先不給開：離開詳情頁會停掉改寫。
    private func derivedRow(_ transcript: Transcript) -> some View {
        Button {
            onOpen(transcript)
        } label: {
            HStack(spacing: Token.Space.m) {
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text(Self.headline(for: transcript))
                        .foregroundStyle(Token.Colors.textPrimary)
                        .lineLimit(2)
                    derivedDetails(transcript)
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .disabled(rewritingKind != nil)
    }

    @ViewBuilder
    private func derivedDetails(_ transcript: Transcript) -> some View {
        Text(Self.subtitle(kind: transcript.sourceKind, createdAt: transcript.createdAt))
        if let instruction = transcript.sourceInstruction {
            Text("補充：" + instruction)
        }
    }

    private func rewriteRow(_ rewrite: TranscriptRewrite) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text(RewriteKind.title(forStored: rewrite.kind))
                .foregroundStyle(Token.Colors.textPrimary)
            Text(rewrite.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
            if let instruction = rewrite.instruction {
                Text("補充：" + instruction)
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
