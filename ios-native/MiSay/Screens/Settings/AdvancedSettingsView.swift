import SwiftUI

/// 設定 →「進階」子頁：錄音、編輯框、診斷紀錄。2026-11-08 設定頁簡化時從第一層收進來，
/// 平常不用碰的放這裡。2026-11-26 米（QC-0014）：說明都拿掉。
/// 2026-11-26 照蔬菜家族規格：備份與清除所有資料搬到設定頁第一層的「資料」區。
struct AdvancedSettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("錄音中先整理只用 Wi-Fi", isOn: $settings.liveTranscriptionWiFiOnly)
            }
            .font(Token.Fonts.body)
            .listRowBackground(Token.Colors.rowBackground)

            Section {
                Toggle("錄音一直留著", isOn: $settings.keepsRecordingsForever)
            }
            .font(Token.Fonts.body)
            .listRowBackground(Token.Colors.rowBackground)

            Section {
                Toggle("用舊的編輯框", isOn: usesOldEditor)
            }
            .font(Token.Fonts.body)
            .listRowBackground(Token.Colors.rowBackground)

            Section {
                ShareLink(
                    item: DiagnosticFile(),
                    preview: SharePreview(DiagnosticFile.fileName)
                ) {
                    Text("匯出診斷紀錄")
                }
                .tint(Token.Colors.link)
            }
            .font(Token.Fonts.body)
            .listRowBackground(Token.Colors.rowBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .navigationTitle("進階")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 存的是「用新的」，畫面上問的是「用舊的」，所以反過來。
    private var usesOldEditor: Binding<Bool> {
        Binding(
            get: { !settings.usesPlainEditor },
            set: { settings.usesPlainEditor = !$0 }
        )
    }
}
