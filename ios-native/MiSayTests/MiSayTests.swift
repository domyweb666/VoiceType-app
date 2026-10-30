import XCTest

final class MiSayTests: XCTestCase {
    /// 骨架測試：證明測試這條水管通，而且 App 的身分跟上架設定一致（標準清單第 5 條）。
    func testAppIdentityMatchesReleaseSettings() {
        let hostApp = Bundle.main
        XCTAssertEqual(hostApp.bundleIdentifier, "org.domyweb.misay")

        let displayName = hostApp.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        XCTAssertEqual(displayName, "米說")
    }
}
