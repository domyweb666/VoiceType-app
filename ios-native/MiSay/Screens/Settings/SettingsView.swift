import SwiftUI

/// 設定（推入頁）。片 B3 做金鑰那一區；自動複製、詞彙、提示詞、模型是組塊 F。
/// 金鑰只在這一頁看得到，而且預設遮住（安全標準一）。存進 M6、驗證走 M11，這頁不碰網路也不碰 Keychain 細節。
/// 2026-11-07 統一風格：推入列右邊帶現況（幾個詞、提示詞是不是預設），次要字用 `textSecondary`；
/// `KeyStatus` 搬到 `SettingsView+KeyStatus.swift`。
struct SettingsView: View {
    /// 首次體驗檔第一節：金鑰欄旁要有「去申請」。網址是 OpenAI 的金鑰頁。
    private static let applyURL = URL(string: "https://platform.openai.com/api-keys")

    private let keyStore = APIKeyStore()
    @State private var keyText = ""
    @State private var isRevealed = false
    @State private var isVerifying = false
    @State private var status: KeyStatus?
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            PageHeading(title: "設定")
            Section {
                keyField
                verifyButton
                if let status {
                    statusRow(status)
                }
                deleteButton
            } header: {
                // iOS 預設把區塊標題轉大寫；詞彙表要的是「OpenAI 金鑰（API Key）」原樣。
                Text("OpenAI 金鑰（API Key）").textCase(nil)
            } footer: {
                if let url = Self.applyURL {
                    Link("去申請金鑰", destination: url)
                        .font(Token.Fonts.footnote)
                        .tint(Token.Colors.link)
                }
            }
            .listRowBackground(Token.Colors.rowBackground)
            polishSection
            habitsSection
            BackupSection()
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .pageTitle("設定")
        .task { loadKey() }
    }

    /// 預設點點；眼睛按一下換成看得到的欄。兩個欄共用同一個字串，切換不會掉字。
    private var keyField: some View {
        HStack {
            Group {
                if isRevealed {
                    TextField("", text: $keyText, prompt: prompt)
                } else {
                    SecureField("", text: $keyText, prompt: prompt)
                }
            }
            .font(Token.Fonts.body)
            .foregroundStyle(Token.Colors.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .frame(width: Token.Shape.minTap, height: Token.Shape.minTap)
            }
            .buttonStyle(.borderless)
            .tint(Token.Colors.link)
            .accessibilityLabel(isRevealed ? "隱藏金鑰" : "顯示金鑰")
        }
    }

    /// placeholder 用 textSecondary，不用系統的 tertiaryLabel（使用規則第 6 條）。
    private var prompt: Text {
        Text("貼上金鑰").foregroundStyle(Token.Colors.textSecondary)
    }

    private var verifyButton: some View {
        Button {
            Task { await saveAndVerify() }
        } label: {
            Text(isVerifying ? "驗證中…" : "儲存並驗證")
                .font(Token.Fonts.body)
        }
        .tint(Token.Colors.link)
        .disabled(isVerifying)
    }

    private var deleteButton: some View {
        Button("刪除金鑰", role: .destructive) {
            deleteKey()
        }
        .font(Token.Fonts.body)
        .tint(Token.Colors.danger)
    }

    /// 圖示＋文字一起出現，顏色不單獨承載意義（使用規則第 4 條）。
    private func statusRow(_ status: KeyStatus) -> some View {
        let symbol = status.isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        return HStack(alignment: .firstTextBaseline, spacing: Token.Space.s) {
            Image(systemName: symbol)
                .foregroundStyle(status.isGood ? Token.Colors.link : Token.Colors.danger)
                .accessibilityHidden(true)
            Text(status.message)
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    @MainActor
    private func loadKey() {
        do {
            keyText = try keyStore.read() ?? ""
        } catch {
            status = .loadFailed
        }
    }

    /// 先存再驗：沒網路也不白貼（PRD「沒網路也能錄」）。存失敗就不驗，不讓人以為存好了。
    @MainActor
    private func saveAndVerify() async {
        // 按鈕變灰之前的那一瞬間再點一下也不送第二次。
        guard !isVerifying else {
            return
        }
        let trimmedKey = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            status = .empty
            return
        }
        isVerifying = true
        defer { isVerifying = false }

        do {
            try keyStore.save(trimmedKey)
        } catch {
            status = .saveFailed
            return
        }
        keyText = trimmedKey

        do {
            try await OpenAIClient().verifyAPIKey()
            status = .usable
        } catch let failure as OpenAIClient.Failure {
            status = KeyStatus(verifyFailure: failure)
        } catch {
            // 剛存好卻讀不回來（APIKeyStore.Failure）：當讀取失敗講，不假裝驗過。
            status = .loadFailed
        }
    }

    @MainActor
    private func deleteKey() {
        do {
            try keyStore.delete()
            keyText = ""
            status = nil
        } catch {
            status = .deleteFailed
        }
    }
}

/// 潤飾、使用習慣、關於（片 F1～F5）；「資料」在 `BackupSection`（組塊 G）。改了馬上存（M7），下一筆整理就照新的走。
private extension SettingsView {
    var polishSection: some View {
        Section {
            Picker("模型", selection: $settings.polishModel) {
                ForEach(AppSettings.polishModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            NavigationLink {
                VocabularyView()
            } label: {
                detailRow("自訂詞彙", value: "\(settings.vocabulary.count) 個")
            }
            // 2026-11-08 米：提示詞不給改，改成二選一。
            Picker("潤飾方式", selection: $settings.polishStyle) {
                ForEach(PolishStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
        } header: {
            Text("潤飾")
        } footer: {
            Text(Self.styleNote + Self.modelNote)
                .font(Token.Fonts.footnote)
        }
        .font(Token.Fonts.body)
        .listRowBackground(Token.Colors.rowBackground)
    }

    /// 推入列右邊帶現況，讓人不用點進去就知道裡面有沒有東西。
    func detailRow(_ title: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(Token.Colors.textSecondary)
        } label: {
            Text(title)
        }
    }

    /// 字級與深色模式不給開關：跟 iPhone 的設定走（片 F5），這裡只講一句讓人知道去哪調。
    var habitsSection: some View {
        Section {
            Toggle("整理好自動複製", isOn: $settings.autoCopy)
                .tint(Token.Colors.link)
        } header: {
            Text("使用習慣")
        } footer: {
            Text("關掉後，整理好不會動到剪貼簿。文字大小和深色模式跟著 iPhone 的設定走。")
                .font(Token.Fonts.footnote)
        }
        .font(Token.Fonts.body)
        .listRowBackground(Token.Colors.rowBackground)
    }

    var aboutSection: some View {
        Section {
            detailRow("版本", value: Self.versionText)
            ShareLink(
                item: DiagnosticFile(),
                preview: SharePreview(DiagnosticFile.fileName)
            ) {
                Text("匯出診斷紀錄")
            }
            .tint(Token.Colors.link)
        } header: {
            Text("關於米說")
        } footer: {
            Text("診斷紀錄只有時間、事件和數字，沒有金鑰、錄音和文字稿，查問題時用。")
                .font(Token.Fonts.footnote)
        }
        .font(Token.Fonts.body)
        .listRowBackground(Token.Colors.rowBackground)
    }

    /// 兩種潤飾各一句，講刪到哪裡；重新潤飾也照這裡選的走。
    static let styleNote = "保留原聲只刪卡詞、重講和句首的「那」「然後」，留住你講話的節奏。"
        + "大幅潤飾會為了通順拆句、改語法，刪得比較多。重新潤飾也照這裡選的走。\n"

    /// 模型名稱與狀態 2026-11-01 查證（見 `Polisher`）；價格會變，這裡不寫數字。
    static var modelNote: String {
        "\(Polisher.defaultModel) 是預設，跟網頁版一樣。"
            + "\(Polisher.alternativeModel) 比較便宜，但 OpenAI 已經說要停用。"
            + "這篇用哪個模型，文字稿詳情看得到。"
    }

    /// 「0.1.4（5）」：版本號＋建置號，回報問題時對得上 TestFlight 那一版。
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version)（\(build)）"
    }
}
