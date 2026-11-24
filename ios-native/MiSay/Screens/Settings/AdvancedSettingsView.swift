import SwiftUI

/// 設定 →「進階」子頁：錄音、編輯框、備份、診斷紀錄、刪除全部資料（S2-9）。2026-11-08 設定頁簡化時從第一層收進來，
/// 平常不用碰的放這裡，說明文字也跟著搬進來。
struct AdvancedSettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("錄音中先整理只用 Wi-Fi", isOn: $settings.liveTranscriptionWiFiOnly)
            } footer: {
                Text(Self.liveTranscriptionNote)
                    .font(Token.Fonts.footnote)
            }
            .font(Token.Fonts.body)
            .listRowBackground(Token.Colors.rowBackground)

            Section {
                Toggle("錄音一直留著", isOn: $settings.keepsRecordingsForever)
            } footer: {
                Text(Self.keepRecordingsNote)
                    .font(Token.Fonts.footnote)
            }
            .font(Token.Fonts.body)
            .listRowBackground(Token.Colors.rowBackground)

            Section {
                Toggle("新的編輯框（試用）", isOn: $settings.usesPlainEditor)
            } footer: {
                Text(Self.plainEditorNote)
                    .font(Token.Fonts.footnote)
            }
            .font(Token.Fonts.body)
            .listRowBackground(Token.Colors.rowBackground)

            BackupSection()

            Section {
                ShareLink(
                    item: DiagnosticFile(),
                    preview: SharePreview(DiagnosticFile.fileName)
                ) {
                    Text("匯出診斷紀錄")
                }
                .tint(Token.Colors.link)
            } footer: {
                Text("診斷紀錄只有時間、事件和數字，沒有金鑰、錄音和文字稿，查問題時用。")
                    .font(Token.Fonts.footnote)
            }
            .font(Token.Fonts.body)
            .listRowBackground(Token.Colors.rowBackground)

            EraseAllDataSection()
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .navigationTitle("進階")
        .navigationBarTitleDisplayMode(.inline)
    }

    static let keepRecordingsNote = "關著時，文字稿存好後錄音留 7 天就刪。打開後一直留著，"
        + "隨時能聽原音、重新轉錄；壓縮後每小時約 14 MB。那篇文字稿刪了，錄音跟著刪。"

    static let plainEditorNote = "文字稿很長時打字會慢、或從「大綱與尋找」點了沒有捲到那一段，就打開試試。"
        + "能做的事一樣，下次打開文字稿生效。看到正文一片白或字打不進去，關掉就回到原本的。"

    static let liveTranscriptionNote = "錄音中每講滿約 5 分鐘就先送去轉成文字，按停止後很快就好。"
        + "關著時，走路也會用行動網路，每小時約 14 MB。"
}
