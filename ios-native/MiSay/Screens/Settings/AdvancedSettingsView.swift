import SwiftUI

/// 設定 →「進階」子頁：潤飾模型、備份、診斷紀錄、刪除全部資料（S2-9）。2026-11-08 設定頁簡化時從第一層收進來，
/// 平常不用碰的放這裡，說明文字也跟著搬進來。
struct AdvancedSettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Picker("潤飾模型", selection: $settings.polishModel) {
                    ForEach(AppSettings.polishModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            } footer: {
                Text(Self.modelNote)
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

    /// 模型名稱與狀態 2026-11-01 查證（見 `Polisher`）；價格會變，這裡不寫數字。
    static var modelNote: String {
        "\(Polisher.defaultModel) 是預設，跟網頁版一樣。"
            + "\(Polisher.alternativeModel) 比較便宜，但 OpenAI 已經說要停用。"
            + "這篇用哪個模型，文字稿的「⋯」裡看得到。"
    }
}
