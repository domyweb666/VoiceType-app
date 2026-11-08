import SwiftUI

/// 設定 →「OpenAI 金鑰」子頁（片 B3）。2026-11-08 設定頁簡化時從第一層搬進來。
/// 金鑰只在這一頁看得到，而且預設遮住（安全標準一）。存進 M6、驗證走 M11，這頁不碰網路也不碰 Keychain 細節。
struct APIKeySettingsView: View {
    /// 首次體驗檔第一節：金鑰欄旁要有「去申請」。網址是 OpenAI 的金鑰頁。
    private static let applyURL = URL(string: "https://platform.openai.com/api-keys")

    private let keyStore = APIKeyStore()
    @State private var keyText = ""
    @State private var isRevealed = false
    @State private var isVerifying = false
    @State private var status: SettingsView.KeyStatus?

    var body: some View {
        Form {
            Section {
                keyField
                verifyButton
                if let status {
                    statusRow(status)
                }
                deleteButton
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
        .navigationTitle("OpenAI 金鑰（API Key）")
        .navigationBarTitleDisplayMode(.inline)
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
    private func statusRow(_ status: SettingsView.KeyStatus) -> some View {
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
            status = SettingsView.KeyStatus(verifyFailure: failure)
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
