@testable import MiSay
import XCTest

/// 2026-11-25 自動加入詞彙改在手機上認字：找改過的地方、讀起來像不像、收哪個詞、詞彙怎麼加怎麼刪。
final class CorrectedWordsTests: XCTestCase {
    private let suiteName = "CorrectedWordsTests"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    // MARK: - 找改過的地方

    func test換字會抓到改前改後和前後文() throws {
        let hunks = EditDiff.hunks(from: "下午去全連買東西。", to: "下午去全聯買東西。")

        let hunk = try XCTUnwrap(hunks.first)
        XCTAssertEqual(hunks.count, 1)
        XCTAssertEqual(hunk.before, "連")
        XCTAssertEqual(hunk.after, "聯")
        XCTAssertEqual(hunk.leading, "下午去全")
        XCTAssertEqual(hunk.trailing, "買東西。")
    }

    func test只改標點空白不算修改() {
        XCTAssertEqual(EditDiff.hunks(from: "好，我知道了", to: "好。我知道了！"), [])
    }

    func test兩處分開的修改算兩處() {
        let hunks = EditDiff.hunks(from: "我想說那個米說很好用然後就這樣", to: "我想說米說很好用，就這樣")
        XCTAssertEqual(hunks.count, 2)
    }

    func test英文單字整個算一格() throws {
        let hunk = try XCTUnwrap(EditDiff.hunks(from: "用Cloud寫", to: "用Claude寫").first)
        XCTAssertEqual(hunk.before, "Cloud")
        XCTAssertEqual(hunk.after, "Claude")
    }

    func test沒看過的修改從原稿算起_看過就從看過那份算() {
        var transcript = Transcript(durationSeconds: 1, rawText: "x")
        transcript.applyPolish("原稿", model: "m", style: .keepVoice)
        XCTAssertNil(transcript.unlearnedEdit)

        transcript.draftText = "改過"
        XCTAssertEqual(transcript.unlearnedEdit?.from, "原稿")

        transcript.learnedDraft = "改過"
        XCTAssertNil(transcript.unlearnedEdit)
    }

    // MARK: - 讀起來像不像

    func test同音和台灣口音常混的算像() {
        XCTAssertTrue(SoundAlike.matches("連", "聯"))
        XCTAssertTrue(SoundAlike.matches("平果", "蘋果"))
        XCTAssertTrue(SoundAlike.matches("三", "山"))
        XCTAssertTrue(SoundAlike.matches("並章", "炳彰"))
        XCTAssertTrue(SoundAlike.matches("陳秉章", "陳炳彰"))
    }

    func test換說法不算像() {
        XCTAssertFalse(SoundAlike.matches("面", "聯"))
        XCTAssertFalse(SoundAlike.matches("非常", "很"))
        XCTAssertFalse(SoundAlike.matches("高興", "開心"))
        XCTAssertFalse(SoundAlike.matches("蘋果", "Apple"))
        XCTAssertFalse(SoundAlike.matches("臉書", "Facebook"))
        XCTAssertFalse(SoundAlike.matches("good", "great"))
    }

    func test中文聽錯的英文品牌算像() {
        XCTAssertTrue(SoundAlike.matches("克勞德", "Claude"))
        XCTAssertTrue(SoundAlike.matches("歐噴AI", "OpenAI"))
        XCTAssertTrue(SoundAlike.matches("openai", "OpenAI"))
        XCTAssertTrue(SoundAlike.matches("Cloud", "Claude"))
    }

    // MARK: - 收哪個詞

    func test改一個字收整個詞() {
        XCTAssertEqual(words("我買了平果手機", "我買了蘋果手機"), ["蘋果"])
        XCTAssertEqual(words("我以經到了", "我已經到了"), ["已經"])
    }

    func test斷詞不認得的店名跟旁邊那個字併起來() {
        XCTAssertEqual(words("下午去全連買東西。", "下午去全聯買東西。"), ["全聯"])
    }

    func test英文品牌收整個單字() {
        XCTAssertEqual(words("我用克勞德寫文章", "我用Claude寫文章"), ["Claude"])
        XCTAssertEqual(words("問歐噴AI就好", "問OpenAI就好"), ["OpenAI"])
    }

    func test改虛字_加字_刪字_換說法都不收() {
        XCTAssertEqual(words("他跑的很快", "他跑得很快"), [])
        XCTAssertEqual(words("我再家", "我在家"), [])
        XCTAssertEqual(words("今天天氣好", "今天天氣真好"), [])
        XCTAssertEqual(words("然後我就走了", "我就走了"), [])
        XCTAssertEqual(words("我很高興", "我很開心"), [])
    }

    func test改數字_改英文文法_整串虛字都不收() {
        XCTAssertEqual(words("Q1的業績", "Q2的業績"), [])
        XCTAssertEqual(words("I make it", "I made it"), [])
        XCTAssertEqual(words("跑的在快", "跑得再快"), [])
    }

    func test加一段刪一段之後別段改的字照樣收() {
        XCTAssertEqual(words("第一段\n我買了平果手機", "我買了蘋果手機"), ["蘋果"])
        XCTAssertEqual(words("我買了平果手機\n尾巴", "新的一段\n我買了蘋果手機\n尾巴"), ["蘋果"])
    }

    func test整篇重寫不比也不會當掉() {
        let old = (0 ..< 15000).map { String(UnicodeScalar(0x4E00 + $0 % 5000) ?? "一") }.joined()
        let new = (0 ..< 15000).map { String(UnicodeScalar(0x6E00 + $0 % 5000) ?? "一") }.joined()
        XCTAssertEqual(EditDiff.hunks(from: old, to: new), [])
    }

    func test同一個詞改好幾處只收一次() {
        XCTAssertEqual(words("平果好吃，平果便宜", "蘋果好吃，蘋果便宜"), ["蘋果"])
    }

    // MARK: - 詞彙

    func test自動詞彙不重複_刪過的不再加回來() throws {
        let settings = try makeSettings()
        settings.vocabulary = ["DOMYWEB"]

        XCTAssertEqual(settings.addAutoVocabulary(["domyweb", "全聯", "全聯"]), ["全聯"])
        XCTAssertTrue(settings.isAutoAdded("全聯"))
        XCTAssertFalse(settings.isAutoAdded("DOMYWEB"))

        settings.removeVocabulary("全聯")
        XCTAssertEqual(settings.vocabulary, ["DOMYWEB"])
        XCTAssertEqual(settings.addAutoVocabulary(["全聯"]), [])
    }

    func test自動詞彙滿了先刪最舊的自動詞_手動的不動() throws {
        let settings = try makeSettings()
        settings.vocabulary = ["手動"]
        let words = (1 ... AppSettings.maxAutoVocabulary + 1).map { "詞\($0)" }
        settings.addAutoVocabulary(words)

        XCTAssertTrue(settings.vocabulary.contains("手動"))
        XCTAssertFalse(settings.vocabulary.contains("詞1"))
        XCTAssertEqual(settings.vocabulary.count, AppSettings.maxAutoVocabulary + 1)
    }

    func test預設自動詞彙開() throws {
        XCTAssertTrue(try makeSettings().autoVocabulary)
    }

    // MARK: - 工具

    private func words(_ old: String, _ new: String) -> [String] {
        CorrectedWords.find(from: old, to: new)
    }

    private func makeSettings() throws -> AppSettings {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }
}
