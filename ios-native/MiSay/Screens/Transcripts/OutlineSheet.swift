import SwiftUI

/// 「大綱與尋找」（2026-11-15 米：要在手機上寫五千字以上）：上面一格尋找，沒打字時列出這篇的標題
/// （沒有標題就列每一段的開頭），點了回到編輯框、游標放在那裡；打了字就列出找到的每一處。
/// 第二批：找到之後可以全部換成別的字；大綱按「搬動」可以拖，整段跟著走。
struct OutlineSheet: View {
    let text: String
    /// 要跳到第幾個字到第幾個字（只放游標就是空的範圍）。
    let onJump: (Range<Int>) -> Void
    /// 全部取代：要找的字、換成什麼。
    let onReplaceAll: (String, String) -> Void
    /// 搬動之後整篇的新樣子。
    let onReorder: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var replacement = ""
    @State private var isReordering = false
    @State private var moveCount = 0

    static let noHeadingNote = "這篇還沒有標題，先列出每一段的開頭。"
        + "在一行的開頭按鍵盤上方的「#」，那一行就是標題，會排在這裡。"
    static let reorderNote = "按住右邊的三條線拖。標題底下到下一個標題之前的字會跟著一起搬。"

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    searchSections
                } else {
                    outlineSection
                }
            }
            .environment(\.editMode, .constant(isReordering ? .active : .inactive))
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "在這篇裡找"
            )
            .overlay { emptyNote }
            .sensoryFeedback(Token.Haptics.reordered, trigger: moveCount)
            .navigationTitle("大綱與尋找")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { reorderButton }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    /// 「找到 3 處」；滿了就講只列前面幾處。
    static func matchTitle(count: Int) -> String {
        count >= DraftOutline.maxMatches ? "只列前 \(count) 處" : "找到 \(count) 處"
    }

    /// 「全部換掉（3 處）」；沒填要換成什麼就是刪掉；列滿了不寫幾處（實際可能更多）。
    static func replaceTitle(count: Int, isDeleting: Bool) -> String {
        let verb = isDeleting ? "全部刪掉" : "全部換掉"
        return count >= DraftOutline.maxMatches ? verb : verb + "（\(count) 處）"
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var headings: [DraftOutline.Entry] {
        DraftOutline.headings(in: text)
    }

    private var outline: [DraftOutline.Entry] {
        headings.isEmpty ? DraftOutline.paragraphs(in: text) : headings
    }

    private var matches: [DraftOutline.Entry] {
        DraftOutline.matches(of: query, in: text)
    }

    @ViewBuilder
    private var searchSections: some View {
        if !matches.isEmpty {
            Section {
                TextField("換成…（不填就是刪掉）", text: $replacement)
                    .autocorrectionDisabled()
                Button(Self.replaceTitle(count: matches.count, isDeleting: replacement.isEmpty)) {
                    onReplaceAll(query, replacement)
                    dismiss()
                }
                .tint(Token.Colors.link)
            }
            .listRowBackground(Token.Colors.rowBackground)
        }
        Section(Self.matchTitle(count: matches.count)) {
            ForEach(matches) { row($0) }
        }
    }

    private var outlineSection: some View {
        Section {
            ForEach(outline) { row($0) }
                .onMove(perform: move)
        } header: {
            Text(headings.isEmpty ? "段落" : "標題")
        } footer: {
            if isReordering {
                Text(Self.reorderNote)
                    .font(Token.Fonts.footnote)
            } else if headings.isEmpty, !outline.isEmpty {
                Text(Self.noHeadingNote)
                    .font(Token.Fonts.footnote)
            }
        }
    }

    /// 至少兩列才有得搬；在找字時不給搬。
    @ViewBuilder
    private var reorderButton: some View {
        if !isSearching, outline.count > 1 {
            Button(isReordering ? "排好了" : "搬動") {
                isReordering.toggle()
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard let first = source.first else {
            return
        }
        onReorder(DraftOutline.moving(outline, from: first, toOffset: destination, in: text))
        moveCount += 1
    }

    @ViewBuilder
    private var emptyNote: some View {
        if isSearching, matches.isEmpty {
            ContentUnavailableView {
                Label("沒有找到", systemImage: "magnifyingglass")
            } description: {
                Text("這篇裡沒有『\(query)』")
            }
        } else if !isSearching, outline.isEmpty {
            ContentUnavailableView("這篇還是空的", systemImage: "doc")
        }
    }

    private func row(_ entry: DraftOutline.Entry) -> some View {
        Button {
            onJump(entry.range)
            dismiss()
        } label: {
            Text(entry.title)
                .font(entry.level == 1 ? Token.Fonts.rowTitle : Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineLimit(2)
                .padding(.leading, CGFloat(entry.level - 1) * Token.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(isReordering)
        .listRowBackground(Token.Colors.rowBackground)
    }
}
