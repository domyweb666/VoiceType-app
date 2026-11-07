import Foundation

/// 「儲存並驗證」之後那一行字。四句照 `.uiux/06-首次體驗.md`；忙線、額度那兩句在 B3 計畫讀稿米放行；
/// 空欄與 Keychain 三句的措辭列在組塊 B 待驗清單給米定。2026-11-07 從設定頁檔搬出來，讓它留在 300 行內。
extension SettingsView {
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
        static let saveFailed = KeyStatus(message: "金鑰沒存好，重開米說再試一次。", isGood: false)
        static let deleteFailed = KeyStatus(message: "金鑰沒刪掉，重開米說再試一次。", isGood: false)
        static let loadFailed = KeyStatus(message: "讀不到存好的金鑰，重開米說再試一次。", isGood: false)

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
}
