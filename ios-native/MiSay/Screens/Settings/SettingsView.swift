import SwiftUI

/// 設定（片 B3、F1～F5、G）。2026-11-08 米：設定頁要簡潔，照 iPhone 設定 App 的做法。
/// 第一層只留短短幾列、右邊帶現況，細節和說明都在子頁：金鑰（`APIKeySettingsView`）、
/// 從修改學習（`LearningSettingsView`）、進階（`AdvancedSettingsView`：模型、備份、診斷紀錄）。
/// 最上面是口述統計（同天米說要從文字稿頁搬過來）。改了馬上存（M7），下一筆整理就照新的走。
/// 2026-11-14 照 domy-design：統計卡淡金底、潤飾方式改淡金膠囊；列與箭頭還是系統的。
struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var hasAPIKey = false
    @State private var stats: DictationStats?

    var body: some View {
        Form {
            if let stats {
                // domy：統計卡自己有淡金底，不疊在白卡上，邊緣貼齊下面的白卡。
                Section {
                    DictationStatsCard(stats: stats)
                        .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)
            }
            Section {
                NavigationLink {
                    APIKeySettingsView()
                } label: {
                    detailRow("OpenAI 金鑰", value: hasAPIKey ? "已設定" : "未設定")
                }
            }
            .listRowBackground(Token.Colors.rowBackground)
            polishSection
            Section {
                NavigationLink("進階") {
                    AdvancedSettingsView()
                }
                detailRow("版本", value: Self.versionText)
            }
            .listRowBackground(Token.Colors.rowBackground)
        }
        .font(Token.Fonts.body)
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .navigationTitle("設定")
        // 切到這個分頁、從子頁返回都會跑：剛存好金鑰、剛錄完一篇，回來就看得到。
        .onAppear { reload() }
    }

    private var polishSection: some View {
        Section {
            // 2026-11-08 米：提示詞不給改，改成二選一。2026-11-14 照 domy：右邊是淡金膠囊，點了開選單。
            LabeledContent("潤飾方式") {
                Menu {
                    Picker("潤飾方式", selection: $settings.polishStyle) {
                        ForEach(PolishStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                } label: {
                    AccentCapsule {
                        Text(settings.polishStyle.title)
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("潤飾方式：\(settings.polishStyle.title)")
                .accessibilityHint("點兩下更改")
            }
            NavigationLink {
                VocabularyView()
            } label: {
                detailRow("自訂詞彙", value: "\(settings.vocabulary.count) 個")
            }
            NavigationLink {
                LearningSettingsView()
            } label: {
                detailRow("從修改學習", value: LearningSettingsView.summary(settings))
            }
            Toggle("整理好自動複製", isOn: $settings.autoCopy)
                .tint(Token.Colors.link)
        } footer: {
            Text(Self.styleNote)
                .font(Token.Fonts.footnote)
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    /// 推入列右邊帶現況，讓人不用點進去就知道裡面有沒有東西。
    private func detailRow(_ title: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(Token.Colors.textSecondary)
        } label: {
            Text(title)
        }
    }

    /// 讀不到 Keychain 就當沒設定；子頁會講讀取失敗。讀不到文字稿就不顯示統計。
    private func reload() {
        let key = (try? APIKeyStore().read()) ?? ""
        hasAPIKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let transcripts = (try? TranscriptStore().loadAll().transcripts) ?? []
        stats = transcripts.isEmpty ? nil : DictationStats(transcripts: transcripts)
    }

    /// 兩種潤飾一句話講完。改了只影響之後錄的，整理好的不會被重做（11/08 重新潤飾拿掉了）。
    static let styleNote = "保留原聲只刪卡詞和重講，留住你講話的節奏；大幅潤飾會拆句、改語法，讀起來比較順。"

    /// 「0.1.4（5）」：版本號＋建置號，回報問題時對得上 TestFlight 那一版。
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version)（\(build)）"
    }
}
