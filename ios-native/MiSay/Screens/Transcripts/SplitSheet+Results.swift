import SwiftUI

/// 「這趟講了幾件事」的結果：一件一列勾起來，底下存成幾篇；存好的、以前拆出來的點了打開。
extension SplitSheet {
    static let singleNote = "這趟講的是同一件事，不用拆。"
    static let staleNote = "你後來改過字，這裡是送出去那時候的字。"

    static func saveButtonTitle(count: Int) -> String {
        count > 0 ? "存成 \(count) 篇" : "勾要存的"
    }

    static func unassignedNote(count: Int) -> String {
        "有 \(count) 段沒有歸到哪一件事，字都還在這篇裡。"
    }

    static func earlierNote(count: Int) -> String {
        "以前拆過 \(count) 篇，存之前看看有沒有重複。"
    }

    static func resultHeader(_ result: TopicSplit) -> String {
        result.isIncomplete ? "沒分好" : "講了 \(result.topics.count) 件事"
    }

    /// 只分出一件時講的話，兩種都不給存。
    static func singleTopicNote(_ result: TopicSplit) -> String {
        guard result.isIncomplete else {
            return singleNote
        }
        return "只分出一件事，還有 \(result.unassignedParagraphs) 段沒歸到。"
            + "按上面的「重新分一次」再試試。"
    }

    /// 「第 1、3～5 段」，連著的併起來。
    static func paragraphNote(_ paragraphs: [Int]) -> String {
        var runs: [ClosedRange<Int>] = []
        for paragraph in paragraphs {
            if let last = runs.last, paragraph == last.upperBound + 1 {
                runs[runs.count - 1] = last.lowerBound ... paragraph
            } else {
                runs.append(paragraph ... paragraph)
            }
        }
        let parts = runs.map { run in
            run.count == 1 ? "\(run.lowerBound)" : "\(run.lowerBound)～\(run.upperBound)"
        }
        return "第 " + parts.joined(separator: "、") + " 段"
    }

    /// 以前拆出來的；這次剛存的上面已經有了。
    var earlierPieces: [Transcript] {
        let currentIDs = Set((session.result?.topics ?? []).map(\.id))
        return pieces.filter { !currentIDs.contains($0.id) }
    }

    func resultSection(_ result: TopicSplit) -> some View {
        Section {
            if result.topics.count > 1 {
                ForEach(result.topics) { topicRow($0) }
            } else {
                Text(Self.singleTopicNote(result))
                    .foregroundStyle(Token.Colors.textPrimary)
            }
        } header: {
            Text(Self.resultHeader(result))
        } footer: {
            resultFooter(result)
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    private func resultFooter(_ result: TopicSplit) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            if result.unassignedParagraphs > 0, !result.isIncomplete {
                Text(Self.unassignedNote(count: result.unassignedParagraphs))
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines) != session.source {
                Text(Self.staleNote)
            }
        }
        .font(Token.Fonts.footnote)
        .foregroundStyle(Token.Colors.textSecondary)
    }

    @ViewBuilder
    private func topicRow(_ topic: SplitTopic) -> some View {
        if session.savedIDs.contains(topic.id) {
            savedRow(topic, piece: pieces.first { $0.id == topic.id })
        } else {
            selectableRow(topic)
        }
    }

    /// 整列點了勾起來或取消，跟清單的選取模式一樣。
    private func selectableRow(_ topic: SplitTopic) -> some View {
        let isSelected = session.selectedIDs.contains(topic.id)
        return Button {
            session.toggle(topic.id)
        } label: {
            HStack(spacing: Token.Space.m) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(Token.Fonts.icon)
                    .foregroundStyle(isSelected ? Token.Colors.link : Token.Colors.textSecondary)
                    .accessibilityHidden(true)
                topicText(topic)
            }
        }
        .accessibilityValue(isSelected ? "已選" : "沒選")
    }

    /// 存好之後又刪掉的找不到那篇：只講存過了，不給開，也不再存一次。
    private func savedRow(_ topic: SplitTopic, piece: Transcript?) -> some View {
        Button {
            if let piece {
                onOpen(piece)
            }
        } label: {
            HStack(spacing: Token.Space.m) {
                topicText(topic)
                Spacer(minLength: Token.Space.s)
                Text(piece == nil ? "存過了" : "已存")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                if piece != nil {
                    openArrow
                }
            }
        }
        .disabled(piece == nil || !canOpen)
    }

    private func topicText(_ topic: SplitTopic) -> some View {
        let characters = DictationStats.countCharacters(topic.text)
        let details = Self.paragraphNote(topic.paragraphs) + "・\(characters.formatted()) 字"
        return VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text(topic.title)
                .foregroundStyle(Token.Colors.textPrimary)
            if !topic.summary.isEmpty, topic.summary != topic.title {
                Text(topic.summary)
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
            Text(details)
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
        }
        .multilineTextAlignment(.leading)
    }

    private var openArrow: some View {
        Image(systemName: "chevron.forward")
            .font(Token.Fonts.footnote)
            .foregroundStyle(Token.Colors.textSecondary)
            .accessibilityHidden(true)
    }

    var earlierSection: some View {
        Section("以前拆出來的") {
            ForEach(earlierPieces) { earlierRow($0) }
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    private func earlierRow(_ piece: Transcript) -> some View {
        Button {
            onOpen(piece)
        } label: {
            HStack(spacing: Token.Space.m) {
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text(RewritesSheet.headline(for: piece))
                        .foregroundStyle(Token.Colors.textPrimary)
                        .lineLimit(2)
                    Text(piece.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                openArrow
            }
        }
        .disabled(!canOpen)
    }

    /// 還有沒存的才出現。重新分的時候先不給存，結果馬上會換掉。
    @ViewBuilder
    var saveBar: some View {
        if !session.unsavedTopics.isEmpty {
            let chosenCount = session.chosenTopics.count
            VStack(spacing: Token.Space.s) {
                if let saveFailure = session.saveFailure {
                    StatusStrip(glyph: .failed, message: saveFailure)
                }
                if !earlierPieces.isEmpty {
                    Text(Self.earlierNote(count: earlierPieces.count))
                        .font(Token.Fonts.footnote)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                Text("勾起來的各存成新的一篇，這篇不會動。")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                Button(Self.saveButtonTitle(count: chosenCount), action: onSave)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(session.chosenTopics.isEmpty || session.isRunning)
            }
            .padding(.horizontal, Token.Space.xl)
            .padding(.bottom, Token.Space.s)
            .background(Token.Colors.groupedBackground)
        }
    }
}
