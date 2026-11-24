import SwiftUI

/// 格式列的「連結」：跳一格問網址，按「加上連結」才插進正文。只收 http／https。
struct LinkSheet: View {
    /// 位置在打開這張頁的時候記好：這張頁的輸入框會把編輯框的焦點拿走。
    struct Request: Identifiable {
        let id = UUID()
        let selection: Range<Int>
        /// 打開時的整份字，按下去時對不上就照前後文找。
        let text: String

        /// 等的時候字可能變了（接著錄的那段插進來）：照前後文找回原本那裡，選到的字還在才動；找不到回 nil。
        func adding(_ url: String, to current: String) -> MarkdownFormatting.Edit? {
            guard current != text else {
                return MarkdownFormatting.addLink(url, in: current, selection: selection)
            }
            let original = Array(text)
            let point = InsertionPoint(offset: selection.lowerBound, in: text)
            guard selection.upperBound <= original.count,
                  let start = point.resolvedOffset(in: current)
            else {
                return nil
            }
            let picked = original[selection]
            guard Array(current).dropFirst(start).starts(with: picked) else {
                return nil
            }
            let moved = start ..< start + picked.count
            return MarkdownFormatting.addLink(url, in: current, selection: moved)
        }
    }

    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var isRejected = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(
                        "https://",
                        text: $input,
                        prompt: Text(verbatim: "https://")
                            .foregroundStyle(Token.Colors.textSecondary)
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit(add)
                    .accessibilityLabel("網址")
                    .listRowBackground(Token.Colors.rowBackground)
                } footer: {
                    Text(isRejected ? Self.rejectedNote : Self.usageNote)
                        .font(Token.Fonts.footnote)
                        .foregroundStyle(
                            isRejected ? Token.Colors.danger : Token.Colors.textSecondary
                        )
                }
            }
            .font(Token.Fonts.body)
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .navigationTitle("連結")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .tint(Token.Colors.link)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加上連結", action: add)
                        .tint(Token.Colors.link)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(Token.Shape.radiusSheet)
        .onAppear { isFocused = true }
    }

    private static let usageNote = "選到的字會變成連結；沒選字就放網址。"
    private static let rejectedNote = "這個不像網址。只收 http 或 https 開頭的。"

    private func add() {
        guard let url = MarkdownFormatting.linkURL(from: input) else {
            isRejected = true
            return
        }
        onAdd(url)
        dismiss()
    }
}
