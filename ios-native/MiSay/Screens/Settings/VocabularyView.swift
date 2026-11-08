import SwiftUI

/// 自訂詞彙（片 F2）：新增、左滑刪除。詞彙進轉錄提示詞與潤飾提示詞，下一筆整理就照新的走。
struct VocabularyView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var newWord = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("", text: $newWord, prompt: prompt)
                        .font(Token.Fonts.body)
                        .foregroundStyle(Token.Colors.textPrimary)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(addWord)
                    Button("新增", action: addWord)
                        .font(Token.Fonts.body.weight(.medium))
                        .tint(Token.Colors.link)
                        .disabled(Self.cleaned(newWord, existing: settings.vocabulary) == nil)
                }
            } footer: {
                Text("常講的人名、品牌、專有名詞。整理時會照這裡的寫法。")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
            .listRowBackground(Token.Colors.rowBackground)

            Section {
                ForEach(settings.vocabulary, id: \.self) { word in
                    Text(word)
                        .font(Token.Fonts.body)
                        .foregroundStyle(Token.Colors.textPrimary)
                }
                .onDelete { offsets in
                    settings.vocabulary.remove(atOffsets: offsets)
                }
            } footer: {
                if !settings.vocabulary.isEmpty {
                    Text("左滑可以刪掉一個。")
                        .font(Token.Fonts.footnote)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
            }
            .listRowBackground(Token.Colors.rowBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .overlay {
            if settings.vocabulary.isEmpty {
                Text("還沒有自訂詞彙")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
        }
        .navigationTitle("自訂詞彙")
        .hidesPageDots()
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

    private var prompt: Text {
        Text("例如 DOMYWEB").foregroundStyle(Token.Colors.textSecondary)
    }

    private func addWord() {
        guard let word = Self.cleaned(newWord, existing: settings.vocabulary) else {
            return
        }
        settings.vocabulary.append(word)
        newWord = ""
    }
}
