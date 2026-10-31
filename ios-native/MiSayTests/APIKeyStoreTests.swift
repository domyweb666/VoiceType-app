@testable import MiSay
import XCTest

/// 片 B1 的六條行為。測試名字用中文寫，米在 CI 紀錄裡看得懂它驗了什麼。
/// 假金鑰刻意長得一看就是假的，而且含中文，不會被 pre-commit 當成真金鑰擋下。
final class APIKeyStoreTests: XCTestCase {
    private let store = APIKeyStore()
    private let fakeKey = "sk-test-假金鑰-不是真的"
    private let anotherFakeKey = "sk-test-第二把假金鑰"

    override func setUpWithError() throws {
        try store.delete()
    }

    override func tearDownWithError() throws {
        try store.delete()
    }

    func test金鑰存進去讀得回來() throws {
        try store.save(fakeKey)
        XCTAssertEqual(try store.read(), fakeKey)
    }

    func test金鑰存第二次會蓋掉第一次() throws {
        try store.save(fakeKey)
        try store.save(anotherFakeKey)
        XCTAssertEqual(try store.read(), anotherFakeKey)
    }

    func test金鑰刪掉之後讀不到() throws {
        try store.save(fakeKey)
        try store.delete()
        XCTAssertNil(try store.read())
    }

    func test金鑰沒存過時讀到的是沒有金鑰() throws {
        XCTAssertNil(try store.read())
    }

    func test金鑰存空字串會被拒絕() {
        XCTAssertThrowsError(try store.save("  \n ")) { error in
            XCTAssertEqual(error as? APIKeyStore.Failure, .emptyKey)
        }
    }

    func test金鑰前後空白會被去掉() throws {
        try store.save("  \(fakeKey)\n")
        XCTAssertEqual(try store.read(), fakeKey)
    }
}
