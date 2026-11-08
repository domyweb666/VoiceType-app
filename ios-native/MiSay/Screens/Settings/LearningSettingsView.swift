import SwiftUI

/// 設定 →「從修改學習」子頁（2026-11-08 米：自動詞彙直接加入、動態改進提示詞要做）。
/// 設定頁簡化時從第一層的一區改成子頁，第一層只留一列寫「開／關」。
/// 兩個開關都關著時什麼都不送；學到的習慣只能看、刪，不給打字改。
struct LearningSettingsView: View {
    @Bindable private var settings = AppSettings.shared

    /// 第一層那一列右邊寫的字：有一個開著就是「開」。
    static func summary(_ settings: AppSettings) -> String {
        settings.isLearningFromEdits ? "開" : "關"
    }

    var body: some View {
        Form {
            section
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .navigationTitle("從修改學習")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var section: some View {
        Section {
            Toggle("自動加入詞彙", isOn: $settings.autoVocabulary)
                .tint(Token.Colors.link)
            Toggle("從我的修改學習", isOn: $settings.learnFromEdits)
                .tint(Token.Colors.link)
            if settings.learnFromEdits || !settings.learnedHabits.isEmpty {
                NavigationLink {
                    LearnedHabitsView()
                } label: {
                    LabeledContent {
                        Text("\(settings.learnedHabits.count) 條")
                            .foregroundStyle(Token.Colors.textSecondary)
                    } label: {
                        Text("學到的習慣")
                    }
                }
            }
        } footer: {
            Text(Self.note)
                .font(Token.Fonts.footnote)
        }
        .font(Token.Fonts.body)
        .listRowBackground(Token.Colors.rowBackground)
    }

    static let note = "你改完文字稿離開時，米說會把改過的那幾段（不是整篇）送去判斷。"
        + "聽錯又被你改對的人名、品牌會自動加進自訂詞彙；打開「從我的修改學習」，"
        + "你的改稿習慣會用在之後的潤飾。兩個都關掉就什麼都不送。"
}

/// 學到的習慣：一條一列，左滑刪一條，最下面全部清掉。
struct LearnedHabitsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var isConfirmingClear = false

    var body: some View {
        List {
            Section {
                ForEach(settings.learnedHabits, id: \.self) { habit in
                    Text(habit)
                        .font(Token.Fonts.body)
                        .foregroundStyle(Token.Colors.textPrimary)
                }
                .onDelete { offsets in
                    settings.learnedHabits.remove(atOffsets: offsets)
                }
            } footer: {
                Text(footer)
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
            .listRowBackground(Token.Colors.rowBackground)

            if !settings.learnedHabits.isEmpty {
                Section {
                    Button("全部清掉", role: .destructive) {
                        isConfirmingClear = true
                    }
                    .tint(Token.Colors.danger)
                }
                .listRowBackground(Token.Colors.rowBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .overlay {
            if settings.learnedHabits.isEmpty {
                Text("還沒學到習慣。改過幾篇文字稿之後會出現在這裡。")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Token.Space.xxl)
            }
        }
        .navigationTitle("學到的習慣")
        .confirmationDialog(
            "清掉全部學到的習慣？",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("全部清掉", role: .destructive) {
                settings.learnedHabits = []
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var footer: String {
        guard !settings.learnedHabits.isEmpty else {
            return ""
        }
        let state = settings.learnFromEdits ? "潤飾時會照這些做。" : "「從我的修改學習」關著，現在不會用。"
        return state + "左滑可以刪掉一條；刪掉的之後有新的修改還可能再學回來。"
    }
}
