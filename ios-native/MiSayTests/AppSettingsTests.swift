@testable import MiSay
import XCTest

/// 片 F1～F4：一般設定的預設值、存回去；2026-11-08 起潤飾是二選一。用自己的 UserDefaults，不碰 App 真的設定。
final class AppSettingsTests: XCTestCase {
    private let suiteName = "AppSettingsTests"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// 每條測試從空的開始。
    private func makeDefaults() throws -> UserDefaults {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func test設定第一次打開自動複製是開的而且模型是預設() throws {
        let defaults = try makeDefaults()
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.autoCopy)
        XCTAssertEqual(settings.polishModel, Polisher.defaultModel)
        XCTAssertEqual(settings.polishStyle, .keepVoice)
        XCTAssertEqual(settings.vocabulary, [])
    }

    func test設定改了之後重開還在() throws {
        let defaults = try makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.autoCopy = false
        settings.vocabulary = ["DOMYWEB"]
        settings.polishModel = Polisher.alternativeModel
        settings.polishStyle = .heavy

        let reopened = AppSettings(defaults: defaults)
        XCTAssertFalse(reopened.autoCopy)
        XCTAssertEqual(reopened.vocabulary, ["DOMYWEB"])
        XCTAssertEqual(reopened.polishModel, Polisher.alternativeModel)
        XCTAssertEqual(reopened.polishStyle, .heavy)
    }

    func test設定以前改過的提示詞不再讀而且認不得的潤飾方式退回保留原聲() throws {
        let defaults = try makeDefaults()
        defaults.set("只改錯字", forKey: "polishPrompt")
        defaults.set("retired-style", forKey: "polishStyle")
        XCTAssertEqual(AppSettings(defaults: defaults).polishStyle, .keepVoice)
    }

    func test設定存著不在名單裡的模型時退回預設() throws {
        let defaults = try makeDefaults()
        defaults.set("gpt-retired", forKey: "polishModel")
        XCTAssertEqual(AppSettings(defaults: defaults).polishModel, Polisher.defaultModel)
    }

    func test設定自訂詞彙空白和重複的不收() {
        XCTAssertEqual(VocabularyView.cleaned("  DOMYWEB ", existing: []), "DOMYWEB")
        XCTAssertNil(VocabularyView.cleaned("   ", existing: []))
        XCTAssertNil(VocabularyView.cleaned("domyweb", existing: ["DOMYWEB"]))
    }

    func test詞彙頁新的在上面_分段與搜尋一起篩() {
        let words = ["DOMYWEB", "全聯", "Domi 老師"]
        let isAuto: (String) -> Bool = { $0 == "全聯" }

        XCTAssertEqual(
            VocabularyView.shownWords(words, filter: .all, search: "", isAutoAdded: isAuto),
            ["Domi 老師", "全聯", "DOMYWEB"]
        )
        XCTAssertEqual(
            VocabularyView.shownWords(words, filter: .auto, search: "", isAutoAdded: isAuto),
            ["全聯"]
        )
        XCTAssertEqual(
            VocabularyView.shownWords(words, filter: .manual, search: " dom ", isAutoAdded: isAuto),
            ["Domi 老師", "DOMYWEB"]
        )
        XCTAssertEqual(
            VocabularyView.shownWords(words, filter: .auto, search: "dom", isAutoAdded: isAuto),
            []
        )
    }

    func test自動加了新詞才記時間_全部被擋掉不記() throws {
        let settings = try AppSettings(defaults: makeDefaults())
        XCTAssertNil(settings.lastAutoVocabularyAt)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        settings.addAutoVocabulary(["全聯"], now: now)
        XCTAssertEqual(settings.lastAutoVocabularyAt, now)

        // 已經有的詞不算新詞，時間不動。
        settings.addAutoVocabulary(["全聯"], now: now.addingTimeInterval(60))
        XCTAssertEqual(settings.lastAutoVocabularyAt, now)
    }
}
