import Foundation
import Observation

/// 方塊 M7：一般設定（模型、詞彙、提示詞與還原、自動複製）。都不是秘密，放 UserDefaults；金鑰在 M6。
/// 外觀與字級跟系統走，不另外存。
@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// 潤飾模型二選一（F4）。名稱 2026-11-01 查證，見 `Polisher`。
    static let polishModels = [Polisher.defaultModel, Polisher.alternativeModel]

    private enum Key {
        static let autoCopy = "autoCopy"
        static let vocabulary = "vocabulary"
        static let polishPrompt = "polishPrompt"
        static let polishModel = "polishModel"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoCopy = defaults.object(forKey: Key.autoCopy) as? Bool ?? true
        vocabulary = defaults.stringArray(forKey: Key.vocabulary) ?? []
        polishPrompt = defaults.string(forKey: Key.polishPrompt) ?? Polisher.defaultPrompt
        let storedModel = defaults.string(forKey: Key.polishModel) ?? Polisher.defaultModel
        polishModel = Self.polishModels.contains(storedModel) ? storedModel : Polisher.defaultModel
    }

    /// 整理完自動複製（F1）。預設開。
    var autoCopy: Bool {
        didSet { defaults.set(autoCopy, forKey: Key.autoCopy) }
    }

    /// 自訂詞彙（F2）：進轉錄提示詞與潤飾提示詞。
    var vocabulary: [String] {
        didSet { defaults.set(vocabulary, forKey: Key.vocabulary) }
    }

    /// 潤飾提示詞（F3）。空字串視同預設。
    var polishPrompt: String {
        didSet { defaults.set(polishPrompt, forKey: Key.polishPrompt) }
    }

    var polishModel: String {
        didSet { defaults.set(polishModel, forKey: Key.polishModel) }
    }

    var isPromptDefault: Bool {
        polishPrompt == Polisher.defaultPrompt
    }

    /// F3「還原預設」：一鍵回到 `Polisher.defaultPrompt` 那一版。
    func resetPolishPrompt() {
        polishPrompt = Polisher.defaultPrompt
    }

    /// 送出去用的提示詞：使用者清空時退回預設，不送空的 system。
    var effectivePolishPrompt: String {
        let trimmed = polishPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Polisher.defaultPrompt : polishPrompt
    }
}
