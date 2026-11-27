import SwiftUI
import VeggieKit

/// 設定（片 B3、F1～F5、G）。2026-11-08 米：設定頁要簡潔，照 iPhone 設定 App 的做法。
/// 2026-11-26 米：補上蔬菜家族共用的幾區，順序照準則 3-3：米說自己的（金鑰、潤飾、進階、口述統計）→
/// 一般 → 資料 → 支援 → 關於 → 頁尾。沒有內購所以沒有購買區；頁尾取代原本的「版本」列。
/// 家族那幾區用 VeggieKit 的列（圖示＋名稱），米說自己的列還是系統的。改了馬上存（M7）。
/// 2026-11-14 照 domy-design：統計卡淡金底、潤飾方式改淡金膠囊。
struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var hasAPIKey = false
    @State private var stats: DictationStats?

    var body: some View {
        Form {
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
            }
            .listRowBackground(Token.Colors.rowBackground)
            if let stats {
                // domy：統計卡自己有淡金底，不疊在白卡上，邊緣貼齊下面的白卡。
                Section {
                    DictationStatsCard(stats: stats)
                        .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)
            }
            SettingsGeneralSection()
            BackupSection()
            // 準則 3-3：清除所有資料是「資料」區最後一列。自己一組，按不了時的那句話才不會跟備份的混在一起。
            EraseAllDataSection()
            SettingsSupportSection()
            SettingsAboutSection()
        }
        .veggieStyle(.misay)
        .font(Token.Fonts.body)
        .scrollContentBackground(.hidden)
        // 米 2026-11-27：卡片離螢幕邊太近，拉到畫面邊距 20。
        .contentMargins(.horizontal, Token.Space.screen, for: .scrollContent)
        // 米 2026-11-27：滑不到最底，頁尾那排連結被懸浮分頁列蓋住。外框墊的那塊傳不進 Form，這裡自己留。
        .contentMargins(.bottom, Token.Shape.tabClearance, for: .scrollContent)
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
            Toggle("整理好自動複製", isOn: $settings.autoCopy)
                .tint(Token.Colors.link)
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
}
