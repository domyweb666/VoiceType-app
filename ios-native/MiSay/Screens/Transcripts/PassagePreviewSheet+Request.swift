import Foundation

extension PassagePreviewSheet {
    /// 一次改一段的請求，兩種編輯框共用。位置記第幾個字：等的時候字可能被改過，舊的 String.Index 不能再用。
    struct Request: Identifiable {
        static let tooLongNote = "選的太長了，一次改 3,000 字以內。整篇要改，用「⋯ → 改寫成…」。"
        static let movedNote = "這段在等的時候被改過了，找不到原本那段，沒有換上。"

        let id = UUID()
        let kind: PassageRewriteKind
        let offset: Int
        private(set) var result: String?
        private(set) var failure: String?
        private(set) var isRunning = false
        private let passage: PassageContext

        /// 沒選到字、選的只有空白，就不開這張頁（nil）。太長的照開，只講原因、不送。
        init?(kind: PassageRewriteKind, in text: String, offset: Int, length: Int) {
            guard let passage = PassageContext(in: text, offset: offset, length: length),
                  !passage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }
            self.kind = kind
            self.offset = offset
            self.passage = passage
            failure = isTooLong ? Self.tooLongNote : nil
        }

        var original: String {
            passage.text
        }

        var isTooLong: Bool {
            passage.text.count > PassageRewriteKind.maxPassageCharacters
        }

        mutating func begin() {
            isRunning = true
            result = nil
            failure = nil
        }

        mutating func finish(result newResult: String) {
            isRunning = false
            result = newResult
        }

        mutating func finish(failure newFailure: String) {
            isRunning = false
            result = nil
            failure = newFailure
        }

        /// 設定都在主執行緒改，也在主執行緒讀。
        @MainActor
        func rewritten(instruction: String?) async throws -> String {
            try await Polisher().rewritePassage(
                passage,
                kind: kind,
                model: AppSettings.shared.polishModel,
                vocabulary: AppSettings.shared.vocabulary,
                instruction: instruction
            )
        }
    }
}
