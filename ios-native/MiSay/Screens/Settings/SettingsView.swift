import SwiftUI

/// 設定（推入頁）。片 B3 做金鑰那一區；自動複製、詞彙、提示詞、模型是組塊 F。
/// 金鑰只在這一頁看得到，而且預設遮住（安全標準一）。存進 M6、驗證走 M11，這頁不碰網路也不碰 Keychain 細節。
struct SettingsView: View {
    /// 「儲存並驗證」之後那一行字。句子照 `.uiux/06-首次體驗.md`；設計檔沒寫的三句在 B3 計畫讀稿列過，米放行。
    struct KeyStatus: Equatable {
        let message: String
        let isGood: Bool

        static let empty = KeyStatus(message: "先貼上金鑰。", isGood: false)
        static let usable = KeyStatus(message: "可以用了", isGood: true)
        static let unusable = KeyStatus(
            message: "OpenAI 說這把金鑰不能用。檢查有沒有少貼一段。",
            isGood: false
        )
        static let quotaExhausted = KeyStatus(
            message: "金鑰存好了，但 OpenAI 說額度用完了，到 OpenAI 後台處理。",
            isGood: false
        )
        static let offline = KeyStatus(
            message: "先存起來了，現在沒網路驗證，下次整理時會再試。",
            isGood: false
        )
        static let openAIBusy = KeyStatus(
            message: "先存起來了，OpenAI 現在忙，下次整理時會再試。",
            isGood: false
        )
        static let saveFailed = KeyStatus(message: "金鑰沒存好，重開 App 再試一次。", isGood: false)
        static let deleteFailed = KeyStatus(message: "金鑰沒刪掉，重開 App 再試一次。", isGood: false)
        static let loadFailed = KeyStatus(message: "讀不到存好的金鑰，重開 App 再試一次。", isGood: false)

        /// M11 的兩堆錯誤翻成給人看的一句：金鑰本身的問題講金鑰，線路的問題講「先存起來了」。
        init(verifyFailure: OpenAIClient.Failure) {
            switch verifyFailure {
            case .invalidAPIKey:
                self = .unusable
            case .quotaExhausted:
                self = .quotaExhausted
            case .timedOut, .transport:
                self = .offline
            case .missingAPIKey:
                self = .loadFailed
            case .rateLimited, .serverError, .rejected, .malformedResponse, .invalidPath:
                self = .openAIBusy
            }
        }

        private init(message: String, isGood: Bool) {
            self.message = message
            self.isGood = isGood
        }
    }

    /// 首次體驗檔第一節：金鑰欄旁要有「去申請」。網址是 OpenAI 的金鑰頁。
    private static let applyURL = URL(string: "https://platform.openai.com/api-keys")

    private let keyStore = APIKeyStore()
    @State private var keyText = ""
    @State private var isRevealed = false
    @State private var isVerifying = false
    @State private var status: KeyStatus?

    var body: some View {
        Form {
            Section {
                keyField
                verifyButton
                if let status {
                    statusRow(status)
                }
                deleteButton
            } header: {
                Text("OpenAI 金鑰（API Key）")
            } footer: {
                if let url = Self.applyURL {
                    Link("去申請金鑰", destination: url)
                        .font(Token.Fonts.footnote)
                        .tint(Token.Colors.link)
                }
            }
            .listRowBackground(Token.Colors.rowBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Token.Colors.groupedBackground)
        .navigationTitle("設定")
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
