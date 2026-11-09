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
        static let liveTranscriptionWiFiOnly = "liveTranscriptionWiFiOnly"
        static let keepsRecordingsForever = "keepsRecordingsForever"
        static let vocabulary = "vocabulary"
        /// 2026-11-08 起不讀舊的 "polishPrompt"（提示詞全文不再給改），只存選了哪一項。
        static let polishStyle = "polishStyle"
        static let polishModel = "polishModel"
        static let hasSeenCostNotice = "hasSeenCostNotice"
        static let autoVocabulary = "autoVocabulary"
        static let autoAddedVocabulary = "autoAddedVocabulary"
        static let rejectedVocabulary = "rejectedVocabulary"
        static let lastAutoVocabularyAt = "lastAutoVocabularyAt"
        static let learnFromEdits = "learnFromEdits"
        static let learnedHabits = "learnedHabits"
    }

    /// 自動加入的詞最多留幾個：轉錄提示詞整段只能 200 字，詞太多會被截掉。
    static let maxAutoVocabulary = 20

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoCopy = defaults.object(forKey: Key.autoCopy) as? Bool ?? true
        liveTranscriptionWiFiOnly = defaults.bool(forKey: Key.liveTranscriptionWiFiOnly)
        keepsRecordingsForever = defaults.bool(forKey: Key.keepsRecordingsForever)
        vocabulary = defaults.stringArray(forKey: Key.vocabulary) ?? []
        let storedStyle = defaults.string(forKey: Key.polishStyle) ?? ""
        polishStyle = PolishStyle(rawValue: storedStyle) ?? PolishStyle.defaultStyle
        let storedModel = defaults.string(forKey: Key.polishModel) ?? Polisher.defaultModel
        polishModel = Self.polishModels.contains(storedModel) ? storedModel : Polisher.defaultModel
        hasSeenCostNotice = defaults.bool(forKey: Key.hasSeenCostNotice)
        autoVocabulary = defaults.object(forKey: Key.autoVocabulary) as? Bool ?? true
        autoAddedVocabulary = defaults.stringArray(forKey: Key.autoAddedVocabulary) ?? []
        rejectedVocabulary = defaults.stringArray(forKey: Key.rejectedVocabulary) ?? []
        lastAutoVocabularyAt = defaults.object(forKey: Key.lastAutoVocabularyAt) as? Date
        learnFromEdits = defaults.bool(forKey: Key.learnFromEdits)
        learnedHabits = defaults.stringArray(forKey: Key.learnedHabits) ?? []
    }

    /// 錄音面板「整理中」那句費用說明只出現第一次（06-首次體驗 錄音面板「第一次」）。
    var hasSeenCostNotice: Bool {
        didSet { defaults.set(hasSeenCostNotice, forKey: Key.hasSeenCostNotice) }
    }

    /// 整理完自動複製（F1）。預設開。
    var autoCopy: Bool {
        didSet { defaults.set(autoCopy, forKey: Key.autoCopy) }
    }

    /// S4-2：錄音中先整理只用 Wi-Fi。預設關（米 11/08 照建議）：走路時沒有 Wi-Fi，開了等於沒有邊錄邊轉。
    var liveTranscriptionWiFiOnly: Bool {
        didSet { defaults.set(liveTranscriptionWiFiOnly, forKey: Key.liveTranscriptionWiFiOnly) }
    }

    /// K4：錄音一直留著（預設關，照舊文字稿存好後留 7 天）。打開時，有文字稿的錄音壓成 m4a 留著。
    var keepsRecordingsForever: Bool {
        didSet { defaults.set(keepsRecordingsForever, forKey: Key.keepsRecordingsForever) }
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

    // MARK: - 2026-11-08 自動詞彙、從修改學習（米選：詞彙直接加入、習慣要做）

    /// 抓到聽錯又被改對的詞，直接加進自訂詞彙。預設開。
    var autoVocabulary: Bool {
        didSet { defaults.set(autoVocabulary, forKey: Key.autoVocabulary) }
    }

    /// 哪些詞是自動加的，舊的在前。詞彙頁標「自動」、滿了先刪最舊的自動詞，手動加的不動。
    private(set) var autoAddedVocabulary: [String] {
        didSet { defaults.set(autoAddedVocabulary, forKey: Key.autoAddedVocabulary) }
    }

    /// 自動加過、被人刪掉的詞，之後不再自動加回來。
    private(set) var rejectedVocabulary: [String] {
        didSet { defaults.set(rejectedVocabulary, forKey: Key.rejectedVocabulary) }
    }

    /// 上次真的自動加進一個新詞的時間；詞彙頁狀態列寫「3 天前」。從沒加過是 nil（2026-11-09）。
    private(set) var lastAutoVocabularyAt: Date? {
        didSet { defaults.set(lastAutoVocabularyAt, forKey: Key.lastAutoVocabularyAt) }
    }

    /// 學到的修改習慣接在潤飾提示詞後面。預設關。
    var learnFromEdits: Bool {
        didSet { defaults.set(learnFromEdits, forKey: Key.learnFromEdits) }
    }

    /// 學到的習慣，最多 10 條。只能刪，不給打字改（11/08「提示詞不給改」）。
    var learnedHabits: [String] {
        didSet { defaults.set(learnedHabits, forKey: Key.learnedHabits) }
    }

    /// 潤飾真的要用的習慣：開關關著就是空的；學到的留著，再打開馬上能用。
    var activeHabits: [String] {
        learnFromEdits ? learnedHabits : []
    }

    /// 兩個都關著就什麼都不學、不送。
    var isLearningFromEdits: Bool {
        autoVocabulary || learnFromEdits
    }

    func isAutoAdded(_ word: String) -> Bool {
        autoAddedVocabulary.contains(word)
    }

    /// 加進自訂詞彙，回真的留下來的那幾個。已經有的、被刪過的不加；超過上限刪最舊的自動詞。
    @discardableResult
    func addAutoVocabulary(_ words: [String], now: Date = .now) -> [String] {
        let existing = Set(vocabulary.map { $0.lowercased() })
        let rejected = Set(rejectedVocabulary.map { $0.lowercased() })
        var added: [String] = []
        for word in words {
            let key = word.lowercased()
            let isNew = !existing.contains(key) && !rejected.contains(key)
            if isNew, !added.contains(where: { $0.lowercased() == key }) {
                added.append(word)
            }
        }
        vocabulary += added
        autoAddedVocabulary += added
        while autoAddedVocabulary.count > Self.maxAutoVocabulary {
            let oldest = autoAddedVocabulary.removeFirst()
            vocabulary.removeAll { $0 == oldest }
        }
        let kept = added.filter { autoAddedVocabulary.contains($0) }
        if !kept.isEmpty {
            lastAutoVocabularyAt = now
        }
        return kept
    }

    /// 詞彙頁左滑刪除。照詞刪不照位置：詞彙頁有篩選與搜尋，畫面上的第幾列對不上清單的第幾個（2026-11-09）。
    /// 刪的是自動加的詞，就記住不再加回來。
    func removeVocabulary(_ word: String) {
        vocabulary.removeAll { $0 == word }
        if autoAddedVocabulary.contains(word) {
            autoAddedVocabulary.removeAll { $0 == word }
            rejectedVocabulary.append(word)
        }
    }
}
