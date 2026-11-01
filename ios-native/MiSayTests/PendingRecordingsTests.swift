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
        // 模擬器不實作資料保護，讀回來是 nil（2026-11-02 CI 實跑確認）；只有真機驗得到這條。
        guard let protection = attributes[.protectionKey] as? FileProtectionType else {
            throw XCTSkip("模擬器不回報檔案保護等級，真機才驗得到")
        }
        XCTAssertEqual(protection, .completeUntilFirstUserAuthentication)
    }

    func test錄音重開撿回沒補檔頭的檔並搬進待轉錄() throws {
        // 片 C4：錄到一半被殺掉的檔長度欄是 0，撿回時補檔頭、搬進待轉錄。
        let abandonedName = "recover-\(UUID().uuidString).wav"
        let abandoned = try Recorder.inProgressDirectoryURL().appending(path: abandonedName)
        var writer = try WAVFileWriter(creatingAt: abandoned)
        try writer.append(pcm: Data(repeating: 3, count: 32000))

        let recovered = try pending.recoverAbandonedRecordings()
        defer { recovered.forEach { try? FileManager.default.removeItem(at: $0) } }

        XCTAssertTrue(recovered.map(\.lastPathComponent).contains(abandoned.lastPathComponent))
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
        let recoveredFile = try XCTUnwrap(recovered.first { $0.lastPathComponent == abandonedName })
        let bytes = try Data(contentsOf: recoveredFile)
        XCTAssertEqual(bytes.littleEndianUInt32(at: 40), 32000)
    }

    func test錄音重開撿回時一個byte都沒錄到的空檔會被丟掉() throws {
        let emptyName = "empty-\(UUID().uuidString).wav"
        let empty = try Recorder.inProgressDirectoryURL().appending(path: emptyName)
        _ = try WAVFileWriter(creatingAt: empty)

        let recovered = try pending.recoverAbandonedRecordings()
        XCTAssertFalse(recovered.map(\.lastPathComponent).contains(empty.lastPathComponent))
        XCTAssertFalse(FileManager.default.fileExists(atPath: empty.path))
    }

    func test錄音待轉錄清單有長度而且刪掉這一個後少一個() throws {
        let sourceName = "list-\(UUID().uuidString).wav"
        let source = FileManager.default.temporaryDirectory.appending(path: sourceName)
        var writer = try WAVFileWriter(creatingAt: source)
        try writer.append(pcm: Data(repeating: 0, count: 64000))
        try writer.finish()
        let accepted = try pending.accept(recordingAt: source)

        let all = try pending.list()
        let listed = try XCTUnwrap(all.first { $0.id == accepted.lastPathComponent })
        XCTAssertEqual(listed.durationSeconds, 2, accuracy: 0.001)

        try pending.delete(listed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: accepted.path))
        XCTAssertFalse(try pending.list().contains(listed))
    }
}
