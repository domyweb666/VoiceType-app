import SwiftUI

/// W4 改一段：上面原本、下面改好的，按「換上」才換進文字稿；按「不要」什麼都不動。
/// 「自己講怎麼改」最上面多一格要求，打好（或用鍵盤的聽寫講）才送，不滿意可以改了再送。
/// 送出與換上在兩種編輯框，這張頁只顯示；請求本身在 `PassagePreviewSheet+Request.swift`。
struct PassagePreviewSheet: View {
    let request: Request
    /// 「自己講怎麼改」那格要求；其他種一打開就送了，用不到。
    let onSend: (String?) -> Void
    let onApply: () -> Void
    let onDiscard: () -> Void

    @State private var instruction = ""
    @FocusState private var isInstructionFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Token.Space.l) {
                    instructionSection
                    passage("原本", text: request.original, color: Token.Colors.textSecondary)
                    outcome
                }
                .padding(Token.Space.l)
            }
            .background(Token.Colors.rowBackground)
            .safeAreaInset(edge: .bottom) { primaryButton }
            .navigationTitle(request.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("不要", action: onDiscard)
                        .tint(Token.Colors.link)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
        .onAppear { isInstructionFocused = asksInstruction }
    }

    private var asksInstruction: Bool {
        request.kind == .custom && !request.isTooLong
    }

    private var instructionCharacters: Int {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var isInstructionTooLong: Bool {
        instructionCharacters > RewriteKind.maxInstructionCharacters
    }

    @ViewBuilder
    private var instructionSection: some View {
        if asksInstruction {
            VStack(alignment: .leading, spacing: Token.Space.s) {
                TextField("例如：開頭先講結論、舉的例子留著", text: $instruction, axis: .vertical)
                    .font(Token.Fonts.body)
                    .lineLimit(2 ... 5)
                    .focused($isInstructionFocused)
                    .padding(Token.Space.m)
                    .background(
                        Token.Colors.sunkenBackground,
                        in: RoundedRectangle(cornerRadius: Token.Shape.radiusField)
                    )
                    .accessibilityLabel("想怎麼改這一段")
                Text(RewritesSheet.instructionNote(characters: instructionCharacters))
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(
                        isInstructionTooLong ? Token.Colors.danger : Token.Colors.textSecondary
                    )
                if request.result != nil {
                    Button("照新的要求再改一次", action: send)
                        .buttonStyle(TextButtonStyle())
                        .disabled(RewriteKind.cleanedInstruction(instruction) == nil)
                }
            }
        }
    }

    @ViewBuilder
    private var outcome: some View {
        if let result = request.result {
            passage("改好的", text: result, color: Token.Colors.textPrimary)
        } else if let failure = request.failure {
            Text(failure)
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.danger)
        } else if request.isRunning {
            ProgressView("改寫中")
                .frame(maxWidth: .infinity)
        }
    }

    /// 這頁的主要按鈕只有一顆：改好了是「換上」，還在問要求時是「照這樣改」。
    @ViewBuilder
    private var primaryButton: some View {
        if request.result != nil {
            Button("換上", action: onApply)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Token.Space.xl)
                .padding(.bottom, Token.Space.s)
        } else if asksInstruction, !request.isRunning {
            Button("照這樣改", action: send)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(RewriteKind.cleanedInstruction(instruction) == nil)
                .padding(.horizontal, Token.Space.xl)
                .padding(.bottom, Token.Space.s)
        }
    }

    /// 空的、太長的不送（`cleanedInstruction` 回 nil）。
    private func send() {
        guard let cleaned = RewriteKind.cleanedInstruction(instruction) else {
            return
        }
        isInstructionFocused = false
        onSend(cleaned)
    }

    private func passage(_ title: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.s) {
            Text(title)
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
            Text(text)
                .font(Token.Fonts.body)
                .foregroundStyle(color)
                .lineSpacing(Token.Space.lineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
