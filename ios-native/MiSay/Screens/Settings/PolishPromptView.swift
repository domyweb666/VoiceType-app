import SwiftUI

/// 潤飾提示詞（片 F3）：直接改、打字就存；「還原預設」一鍵回到 `Polisher.defaultPrompt` 那一版。
/// 清空不算壞：送出時退回預設（`AppSettings.effectivePolishPrompt`），不送空的 system。
struct PolishPromptView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var isConfirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: Token.Space.m) {
            // 不放進 Form：Form 裡的 TextEditor 只有一兩行高，提示詞很長，要整頁給它。
            TextEditor(text: $settings.polishPrompt)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(Token.Space.s)
                .background(
                    Token.Colors.rowBackground,
                    in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow)
                )
            Text("下一筆整理和重新潤飾都會照這裡寫的走。改壞了可以還原。")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
            Button("還原預設") {
                isConfirmingReset = true
            }
            .font(Token.Fonts.body)
            .tint(Token.Colors.link)
            .disabled(settings.isPromptDefault)
        }
        .padding(Token.Space.l)
        .background(Token.Colors.groupedBackground)
        .navigationTitle("潤飾提示詞")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "改過的提示詞會被換回原本那一版。",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("還原預設", role: .destructive) {
                settings.resetPolishPrompt()
            }
            Button("取消", role: .cancel) {}
        }
    }
}
