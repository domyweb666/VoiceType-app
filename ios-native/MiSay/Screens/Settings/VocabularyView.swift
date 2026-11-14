import SwiftUI

/// 自訂詞彙（片 F2）。詞彙進轉錄提示詞與潤飾提示詞，下一筆整理就照新的走。
/// 2026-11-09 米：改成像別家「字典」那頁，自動加的詞一眼看得到：搜尋、自動加入的狀態、
/// 全部／自動／手動分段、右下角＋新增，每個詞帶「自動」或「手動」。注音不做：詞彙是用字送進提示詞的，注音用不到。
struct VocabularyView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "全部"
        case auto = "自動"
        case manual = "手動"

        var id: Self {
            self
        }
    }

    @Bindable private var settings = AppSettings.shared
    @State private var filter = Filter.all
    @State private var searchText = ""
    @State private var isAdding = false
    @State private var newWord = ""
    /// 新增時撞到已經有的詞，底下說一聲；下次新增就清掉。
    @State private var duplicateWord: String?

    var body: some View {
        let shown = Self.shownWords(
            settings.vocabulary,
            filter: filter,
            search: searchText,
            isAutoAdded: settings.isAutoAdded
        )
        List {
            Section {
                learningRow
            }
            .listRowBackground(Token.Colors.rowBackground)

            Section {
                Picker("顯示", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                if shown.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(shown, id: \.self) { word in
                        wordRow(word)
                    }
                    .onDelete { offsets in
                        // 刪掉自動加的詞會記住，之後不再自動加回來（2026-11-08）。
                        offsets.map { shown[$0] }.forEach(settings.removeVocabulary)
                    }
                    .listRowBackground(Token.Colors.rowBackground)
                }
            } footer: {
                footer(isEmpty: shown.isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .searchable(text: $searchText, prompt: "搜尋詞彙")
        .overlay(alignment: .bottomTrailing) { addButton }
        .alert("新增詞彙", isPresented: $isAdding) {
            TextField("例如 DOMYWEB", text: $newWord)
                .autocorrectionDisabled()
            Button("新增", action: addWord)
            Button("取消", role: .cancel) {}
        } message: {
            Text("常講的人名、品牌、專有名詞。整理時會照這裡的寫法。")
        }
        .navigationTitle("自訂詞彙")
    }

    /// 空白去掉；空的、跟現有重複的（不分大小寫）不收，回 nil。
    static func cleaned(_ input: String, existing: [String]) -> String? {
        let word = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else {
            return nil
        }
        let isDuplicate = existing.contains { $0.caseInsensitiveCompare(word) == .orderedSame }
        return isDuplicate ? nil : word
    }

    /// 畫面上要列的詞：新加的在上面，照分段篩，再照搜尋字篩（不分大小寫）。
    static func shownWords(
        _ vocabulary: [String],
        filter: Filter,
        search: String,
        isAutoAdded: (String) -> Bool
    ) -> [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return vocabulary.reversed().filter { word in
            let matchesFilter = switch filter {
            case .all: true
            case .auto: isAutoAdded(word)
            case .manual: !isAutoAdded(word)
            }
            return matchesFilter && (query.isEmpty || word.localizedCaseInsensitiveContains(query))
        }
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        newWord = ""
        guard let word = Self.cleaned(trimmed, existing: settings.vocabulary) else {
            duplicateWord = trimmed.isEmpty ? nil : trimmed
            return
        }
        duplicateWord = nil
        // 剛加的要看得到：回到「全部」、清掉搜尋。
        filter = .all
        searchText = ""
        settings.vocabulary.append(word)
    }
}

/// 詞彙頁的幾塊：自動加入的狀態、一個詞一列、空狀態、底下說明、右下角＋。
private extension VocabularyView {
    /// 整列可點，進「從修改學習」開關那頁。開關的字跟顏色一起講，不只靠顏色（使用規則第 4 條）。
    var learningRow: some View {
        NavigationLink {
            LearningSettingsView()
        } label: {
            HStack(spacing: Token.Space.m) {
                Image(systemName: "circle.fill")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(
                        settings.autoVocabulary ? Token.Colors.link : Token.Colors.textSecondary
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text(settings.autoVocabulary ? "自動加入詞彙：開" : "自動加入詞彙：關")
                        .font(Token.Fonts.body)
                        .foregroundStyle(Token.Colors.textPrimary)
                    Text(learningDetail)
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
            }
        }
    }

    var learningDetail: String {
        guard settings.autoVocabulary else {
            return "關著時不會自己加詞，你加的照樣有用。"
        }
        guard let date = settings.lastAutoVocabularyAt else {
            return "還沒學到新詞。你把聽錯的人名、品牌改對，就會記下來。"
        }
        return "上次加了新詞：" + date.formatted(.relative(presentation: .named))
    }

    func wordRow(_ word: String) -> some View {
        let isAuto = settings.isAutoAdded(word)
        return HStack {
            Text(word)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
            Spacer()
            Label(isAuto ? "自動" : "手動", systemImage: isAuto ? "sparkles" : "pencil")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
        }
    }

    /// 2026-11-08 米選原生：空狀態用系統的 ContentUnavailableView。
    @ViewBuilder
    var emptyState: some View {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if filter == .auto {
            ContentUnavailableView(
                "還沒有自動加的詞",
                systemImage: "sparkles",
                description: Text("你把聽錯的人名、品牌改對，米說會自己記下來。")
            )
        } else {
            ContentUnavailableView(
                filter == .manual ? "還沒有手動加的詞" : "還沒有自訂詞彙",
                systemImage: "character.book.closed",
                description: Text("按右下角的＋加一個。")
            )
        }
    }

    func footer(isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            if let duplicateWord {
                Text("「\(duplicateWord)」已經在裡面了。")
            }
            if !isEmpty {
                Text("左滑可以刪掉一個。標「自動」的是從你改過的文字稿學來的，刪掉就不會再加回來。")
            }
        }
        .font(Token.Fonts.footnote)
        .foregroundStyle(Token.Colors.textSecondary)
    }

    /// 這頁唯一的主要動作，跟 `PrimaryButtonStyle` 同一套（domy：金棕底白字），只是圓的；長相交給系統按鈕。
    @ViewBuilder
    var addButton: some View {
        let button = Button {
            newWord = ""
            isAdding = true
        } label: {
            Image(systemName: "plus")
                .font(Token.Fonts.icon.weight(.semibold))
                .foregroundStyle(Token.Colors.onAccent)
                .frame(width: Token.Shape.minTap, height: Token.Shape.minTap)
        }
        .controlSize(.large)
        .buttonBorderShape(.circle)
        .tint(Token.Colors.accent)
        .accessibilityLabel("新增詞彙")
        .padding(Token.Space.l)

        if #available(iOS 26, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }
}
