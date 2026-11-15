import SwiftUI

/// 「大綱與尋找」（2026-11-15 米：要在手機上寫五千字以上）：上面一格尋找，沒打字時列出這篇的標題
/// （沒有標題就列每一段的開頭），點了回到編輯框、游標放在那裡；打了字就列出找到的每一處。
struct OutlineSheet: View {
    let text: String
    /// 要跳到第幾個字到第幾個字（只放游標就是空的範圍）。
    let onJump: (Range<Int>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    static let noHeadingNote = "這篇還沒有標題，先列出每一段的開頭。"
        + "在一行的開頭按鍵盤上方的「#」，那一行就是標題，會排在這裡。"

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    Section(Self.matchTitle(count: matches.count)) {
                        ForEach(matches) { row($0) }
                    }
                } else {
                    Section {
                        ForEach(outline) { row($0) }
                    } header: {
                        Text(headings.isEmpty ? "段落" : "標題")
                    } footer: {
                        if headings.isEmpty, !outline.isEmpty {
                            Text(Self.noHeadingNote)
                                .font(Token.Fonts.footnote)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "在這篇裡找"
            )
            .overlay { emptyNote }
            .navigationTitle("大綱與尋找")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        .listRowBackground(Token.Colors.rowBackground)
    }
}
