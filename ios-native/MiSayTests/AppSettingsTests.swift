@testable import MiSay
import XCTest

/// 片 F1～F4：一般設定的預設值、存回去、還原。用自己的 UserDefaults，不碰 App 真的設定。
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
        XCTAssertTrue(settings.isPromptDefault)
        XCTAssertEqual(settings.vocabulary, [])
    }

    func test設定改了之後重開還在() throws {
        let defaults = try makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.autoCopy = false
        settings.vocabulary = ["DOMYWEB"]
        settings.polishModel = Polisher.alternativeModel

        let reopened = AppSettings(defaults: defaults)
        XCTAssertFalse(reopened.autoCopy)
        XCTAssertEqual(reopened.vocabulary, ["DOMYWEB"])
        XCTAssertEqual(reopened.polishModel, Polisher.alternativeModel)
    }

    func test設定提示詞改壞了還原預設回到原本那版而且清空時送預設() throws {
        let defaults = try makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.polishPrompt = "   "
        XCTAssertEqual(settings.effectivePolishPrompt, Polisher.defaultPrompt)

        settings.polishPrompt = "只改錯字"
        XCTAssertEqual(settings.effectivePolishPrompt, "只改錯字")
        settings.resetPolishPrompt()
        XCTAssertTrue(settings.isPromptDefault)
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
}
