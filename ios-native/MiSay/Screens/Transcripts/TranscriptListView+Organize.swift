import SwiftUI

/// 文字稿清單的列與 W6 整理（2026-11-09）：列（日期、兩行預覽、標籤）、照標籤篩、選幾篇合併成一篇。
/// 為了讓 `TranscriptListView.swift` 留在 300 行內，列與日期的寫法一起搬過來。
extension TranscriptListView {
    /// 今天、本週（同一個行事曆週）、更早。只是給人看的分組，不影響排序。
    static func groupTitle(
        for date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return todayTitle
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return weekTitle
        }
        return olderTitle
    }

    /// 「10 月 31 日 14:32・3 分 48 秒」（線框詳情頁的副標）。
    static func subtitle(for transcript: Transcript) -> String {
        let date = transcript.createdAt.formatted(date: .abbreviated, time: .shortened)
        return date + "・" + RecordingSheetView.formatSpoken(transcript.durationSeconds)
    }

    /// 「今天」那一組只講時間：「14:32・3 分 48 秒」。
    static func timeSubtitle(for transcript: Transcript) -> String {
        let time = transcript.createdAt.formatted(date: .omitted, time: .shortened)
        return time + "・" + RecordingSheetView.formatSpoken(transcript.durationSeconds)
    }

    func row(_ transcript: Transcript, showsDate: Bool) -> some View {
        let subtitle = showsDate
            ? Self.subtitle(for: transcript)
            : Self.timeSubtitle(for: transcript)
        return VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text(subtitle)
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
            Text(transcript.displayText)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineLimit(2)
            if let tags = transcript.tags, !tags.isEmpty {
                Text(Self.tagLine(tags))
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    /// 「#讀書心得 #課程」
    static func tagLine(_ tags: [String]) -> String {
        tags.map { "#" + $0 }.joined(separator: " ")
    }

    /// 選取模式的列：整列點了勾起來或取消，左邊一個圈。勾的狀態字也講（無障礙），不只靠圖。
    func selectableRow(_ transcript: Transcript, showsDate: Bool) -> some View {
        let isSelected = selectedIDs.contains(transcript.id)
        return Button {
            if isSelected {
                selectedIDs.remove(transcript.id)
            } else {
                selectedIDs.insert(transcript.id)
            }
        } label: {
            HStack(spacing: Token.Space.m) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(Token.Fonts.icon)
                    .foregroundStyle(isSelected ? Token.Colors.link : Token.Colors.textSecondary)
                    .accessibilityHidden(true)
                row(transcript, showsDate: showsDate)
            }
        }
        .accessibilityValue(isSelected ? "已選" : "沒選")
    }

    /// 左上「選取／取消」，右上照標籤看（有標籤才出現）。
    @ToolbarContentBuilder
    var organizeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if transcripts.count >= Transcript.minimumMergeCount || isSelecting {
                Button(isSelecting ? "取消" : "選取") {
                    isSelecting.toggle()
                    selectedIDs = []
                    mergeFailed = false
                }
                .tint(Token.Colors.link)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            let tags = Transcript.tagsInUse(transcripts)
            if !tags.isEmpty || selectedTag != nil {
                Menu {
                    Picker("照標籤看", selection: $selectedTag) {
                        Text("全部文字稿").tag(String?.none)
                        ForEach(tags, id: \.self) { Text("#" + $0).tag(String?.some($0)) }
                    }
                } label: {
                    Image(systemName: selectedTag == nil ? "tag" : "tag.fill")
                }
                .accessibilityLabel("照標籤看")
                .tint(Token.Colors.link)
            }
        }
    }

    /// 選取模式底下：一句說明、合併鈕（這頁唯一的玉米黃）。少於兩篇按不下去。
    var mergeBar: some View {
        VStack(spacing: Token.Space.s) {
            if mergeFailed {
                StatusStrip(glyph: .failed, message: "沒合併成，原本那幾篇都還在。再試一次。")
            }
            Text("照錄的時間接成新的一篇，原本那幾篇不會動。")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
            Button(Self.mergeButtonTitle(selectedCount: selectedIDs.count), action: mergeSelected)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedIDs.count < Transcript.minimumMergeCount)
        }
        .padding(.horizontal, Token.Space.xl)
        .padding(.bottom, Token.Space.s)
        .background(Token.Colors.groupedBackground)
    }

    static func mergeButtonTitle(selectedCount: Int) -> String {
        selectedCount < Transcript.minimumMergeCount ? "選兩篇以上來合併" : "合併成一篇（\(selectedCount) 篇）"
    }

    /// 存好新的那篇才離開選取模式、打開它；存不進去就留在選取模式，說一聲。
    func mergeSelected() {
        let chosen = transcripts.filter { selectedIDs.contains($0.id) }
        guard let merged = Transcript.merged(chosen) else {
            return
        }
        do {
            try TranscriptStore().save(merged)
        } catch {
            mergeFailed = true
            return
        }
        mergeFailed = false
        isSelecting = false
        selectedIDs = []
        reload()
        openedTranscript = merged
    }
}
