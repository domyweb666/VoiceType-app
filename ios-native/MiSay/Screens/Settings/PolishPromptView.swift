import SwiftUI

/// 潤飾提示詞（片 F3）：直接改、打字就存；「還原預設」一鍵回到 `Polisher.defaultPrompt` 那一版。
/// 清空不算壞：送出時退回預設（`AppSettings.effectivePolishPrompt`），不送空的 system。
/// 2026-11-07 統一風格：編輯框放白卡片，「還原預設」是置中的金色文字鈕。
struct PolishPromptView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var isConfirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: Token.Space.m) {
            // 不放進 Form：Form 裡的 TextEditor 只有一兩行高，提示詞很長，要整頁給它。
            TextEditor(text: $settings.polishPrompt)
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineSpacing(Token.Space.xs)
                .scrollContentBackground(.hidden)
                .padding(Token.Space.l)
                .background(
                    Token.Colors.rowBackground,
                    in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow)
                )
            Text("下一筆整理和重新潤飾都會照這裡寫的走。改壞了可以還原。")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
                .padding(.horizontal, Token.Space.xs)
            Button("還原預設") {
                isConfirmingReset = true
            }
            .buttonStyle(TextButtonStyle())
            .disabled(settings.isPromptDefault)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Token.Space.l)
        .padding(.top, Token.Space.m)
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
