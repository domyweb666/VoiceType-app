import Foundation
import Observation

/// 方塊 M7：一般設定（模型、詞彙、潤飾方式、自動複製）。都不是秘密，放 UserDefaults；金鑰在 M6。
/// 外觀與字級跟系統走，不另外存。
@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// 潤飾模型二選一（F4）。名稱 2026-11-01 查證，見 `Polisher`。
    static let polishModels = [Polisher.defaultModel, Polisher.alternativeModel]

    private enum Key {
        static let autoCopy = "autoCopy"
        static let vocabulary = "vocabulary"
        /// 2026-11-08 起不讀舊的 "polishPrompt"（提示詞全文不再給改），只存選了哪一項。
        static let polishStyle = "polishStyle"
        static let polishModel = "polishModel"
        static let hasSeenCostNotice = "hasSeenCostNotice"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoCopy = defaults.object(forKey: Key.autoCopy) as? Bool ?? true
        vocabulary = defaults.stringArray(forKey: Key.vocabulary) ?? []
        let storedStyle = defaults.string(forKey: Key.polishStyle) ?? ""
        polishStyle = PolishStyle(rawValue: storedStyle) ?? PolishStyle.defaultStyle
        let storedModel = defaults.string(forKey: Key.polishModel) ?? Polisher.defaultModel
        polishModel = Self.polishModels.contains(storedModel) ? storedModel : Polisher.defaultModel
        hasSeenCostNotice = defaults.bool(forKey: Key.hasSeenCostNotice)
    }

    /// 錄音面板「整理中」那句費用說明只出現第一次（06-首次體驗 錄音面板「第一次」）。
    var hasSeenCostNotice: Bool {
        didSet { defaults.set(hasSeenCostNotice, forKey: Key.hasSeenCostNotice) }
    }

    /// 整理完自動複製（F1）。預設開。
    var autoCopy: Bool {
        didSet { defaults.set(autoCopy, forKey: Key.autoCopy) }
    }

    /// 自訂詞彙（F2）：進轉錄提示詞與潤飾提示詞。
    var vocabulary: [String] {
        didSet { defaults.set(vocabulary, forKey: Key.vocabulary) }
    }

    /// 潤飾二選一（2026-11-08 取代 F3 的可改提示詞）。預設保留原聲。
    var polishStyle: PolishStyle {
        didSet { defaults.set(polishStyle.rawValue, forKey: Key.polishStyle) }
    }

    var polishModel: String {
        didSet { defaults.set(polishModel, forKey: Key.polishModel) }
    }
}
