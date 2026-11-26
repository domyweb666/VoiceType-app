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
        return date + "・" + lengthNote(for: transcript)
    }

    /// 錄了多久；自己打的新文稿沒有錄音，寫「自己打的」（2026-11-15）；改寫來的寫改成哪一種，拆出來的也講一聲。
    static func lengthNote(for transcript: Transcript) -> String {
        if let kind = transcript.sourceKind {
            return Transcript.originTitle(forStored: kind)
        }
        return transcript.isWritten
            ? "自己打的"
            : RecordingSheetView.formatSpoken(transcript.durationSeconds)
    }

    /// 列右上角的日期，越近越短（2026-11-26 米選設計稿 A）：今天「07:39」、本週「週二」、
    /// 今年「11/17」、更早的年份「2025/11/17」。看的是最後改的時間（清單照它排）。
    static func rowDate(
        for date: Date,
        group: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
        switch group {
        case todayTitle:
            return date.formatted(style.hour().minute())
        case weekTitle:
            return date.formatted(style.weekday(.abbreviated))
        default:
            let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
            let monthDay = style.month(.defaultDigits).day()
            return date.formatted(sameYear ? monthDay : monthDay.year())
        }
    }

    /// 第二行開頭：多長、是不是發布了。「3 分 48 秒・已發布」。
    static func rowDetail(for transcript: Transcript) -> String {
        let status = transcript.publishedAt == nil ? [] : [PublishFilter.published.title]
        return ([lengthNote(for: transcript)] + status).joined(separator: "・")
    }

    /// 沒取標題的篇：開頭第一句當粗體那行，剩下的接在第二行。第一句太長（找不到句號）就整段給第一行，截掉。
    static func splitOpening(_ opening: String) -> (head: String, rest: String) {
        let stops: Set<Character> = ["。", "？", "！", "?", "!", "\n"]
        let window = opening.prefix(headlineSearchLength)
        guard let stop = window.firstIndex(where: { stops.contains($0) }) else {
            return (opening, "")
        }
        var head = String(opening[...stop]).trimmingCharacters(in: .whitespacesAndNewlines)
        if head.hasSuffix("。") {
            head.removeLast()
        }
        let rest = opening[opening.index(after: stop)...]
        return (head, rest.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 第一句在這麼多字內結束才切，不然切出來的第一行也是被截掉的。
    static let headlineSearchLength = 40

    /// 有取標題才有；只有空白不算。
    static func rowTitle(of transcript: Transcript) -> String? {
        let title = (transcript.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    /// 設計稿 A（2026-11-26）：第一行粗體（標題或第一句）＋右邊短日期，第二行灰字「多長・接下去的字」，
    /// 沒有卡片、沒有箭頭，列之間一條細線。
    func row(_ transcript: Transcript, group: String) -> some View {
        let opening = PlainTextExport.opening(of: transcript.displayText)
        let lines = Self.rowTitle(of: transcript).map { (head: $0, rest: opening) }
            ?? Self.splitOpening(opening)
        let second = [Self.rowDetail(for: transcript), lines.rest].filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: Token.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Token.Space.m) {
                Text(lines.head.isEmpty ? Self.emptyHeadline : lines.head)
                    .font(Token.Fonts.rowTitle)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: .zero)
                Text(Self.rowDate(for: transcript.updatedAt, group: group))
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                    .fixedSize()
            }
            Text(second.joined(separator: "・"))
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
                .lineLimit(1)
            if let tags = transcript.tags, !tags.isEmpty {
                Text(Self.tagLine(tags))
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    static let emptyHeadline = "沒有字"

    /// 不用 NavigationLink：編輯頁開著時清單會照最後改的重排，那一列換了位置，推出去的頁會被收掉。
    /// 設計稿 A 拿掉右邊的箭頭，整列還是點得到。
    func openableRow(_ transcript: Transcript, group: String) -> some View {
        Button {
            openedTranscript = transcript
        } label: {
            row(transcript, group: group)
                .multilineTextAlignment(.leading)
                .contentShape(Rectangle())
        }
    }

    /// 「#讀書心得 #課程」
    static func tagLine(_ tags: [String]) -> String {
        tags.map { "#" + $0 }.joined(separator: " ")
    }

    /// 選取模式的列：整列點了勾起來或取消，左邊一個圈。勾的狀態字也講（無障礙），不只靠圖。
    func selectableRow(_ transcript: Transcript, group: String) -> some View {
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
                row(transcript, group: group)
            }
        }
        .accessibilityValue(isSelected ? "已選" : "沒選")
    }

    /// 左上「選取／取消」，右上照標籤、照草稿或已發布看（有東西可以篩才出現）。
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
            if hasFilters {
                Menu {
                    if !tags.isEmpty || selectedTag != nil {
                        Picker("照標籤看", selection: $selectedTag) {
                            Text("全部標籤").tag(String?.none)
                            ForEach(tags, id: \.self) { Text("#" + $0).tag(String?.some($0)) }
                        }
                    }
                    publishPicker
                } label: {
                    Image(systemName: isFiltering ? "tag.fill" : "tag")
                }
                .accessibilityLabel("照標籤或發布狀態看")
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
