@testable import MiSay
import XCTest

/// 片 B3：M11 的錯誤翻成設定頁那一行字。畫面本身米在 TestFlight 親手驗，這裡只鎖文案對應。
final class SettingsViewTests: XCTestCase {
    private typealias KeyStatus = SettingsView.KeyStatus

    func test設定金鑰錯時那行字說金鑰不能用() {
        let status = KeyStatus(verifyFailure: .invalidAPIKey(statusCode: 401))
        XCTAssertEqual(status, .unusable)
        XCTAssertFalse(status.isGood)
        XCTAssertEqual(status.message, "OpenAI 說這把金鑰不能用。檢查有沒有少貼一段。")
    }

    func test設定沒網路或逾時那行字說先存起來了() {
        XCTAssertEqual(KeyStatus(verifyFailure: .transport(.notConnectedToInternet)), .offline)
        XCTAssertEqual(KeyStatus(verifyFailure: .timedOut), .offline)
        XCTAssertEqual(KeyStatus.offline.message, "先存起來了，現在沒網路驗證，下次整理時會再試。")
    }

    func test設定OpenAI忙線或當機那行字說先存起來了() {
        XCTAssertEqual(KeyStatus(verifyFailure: .rateLimited), .openAIBusy)
        XCTAssertEqual(KeyStatus(verifyFailure: .serverError(statusCode: 503)), .openAIBusy)
        XCTAssertEqual(KeyStatus.openAIBusy.message, "先存起來了，OpenAI 現在忙，下次整理時會再試。")
    }

    func test設定額度用完那行字叫人去OpenAI後台() {
        let status = KeyStatus(verifyFailure: .quotaExhausted)
        XCTAssertEqual(status, .quotaExhausted)
        XCTAssertEqual(status.message, "金鑰存好了，但 OpenAI 說額度用完了，到 OpenAI 後台處理。")
    }

    func test設定只有能用那一句是綠的() {
        XCTAssertTrue(KeyStatus.usable.isGood)
        XCTAssertEqual(KeyStatus.usable.message, "可以用了")
        XCTAssertFalse(KeyStatus.empty.isGood)
        XCTAssertFalse(KeyStatus.saveFailed.isGood)
    }
}
