@testable import MiSay
import XCTest

/// 片 C1：待轉錄資料夾。只准在模擬器跑：會在 App 自己的 Application Support 裡建資料夾、搬檔。
final class PendingRecordingsTests: XCTestCase {
    private let pending = PendingRecordings()

    func test錄音收進待轉錄後原檔不在了() throws {
        let name = "move-\(UUID().uuidString).wav"
        let source = FileManager.default.temporaryDirectory.appending(path: name)
        try Data(repeating: 0, count: 44).write(to: source)

        let destination = try pending.accept(recordingAt: source)
        defer { try? FileManager.default.removeItem(at: destination) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(destination.lastPathComponent, source.lastPathComponent)
        XCTAssertEqual(destination.deletingLastPathComponent().lastPathComponent, "Pending")
    }

    /// 「第一次解鎖後可用」是 iOS 的預設等級，這條只擋「有人把它降成 none」，不算安全標準二的證據。
    func test錄音待轉錄資料夾在AppSupport而且有檔案保護() throws {
        let directory = try pending.directoryURL()
        XCTAssertTrue(directory.path.contains("Application Support"))
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        let protection = attributes[.protectionKey] as? FileProtectionType
        XCTAssertEqual(protection, .completeUntilFirstUserAuthentication)
    }
}
