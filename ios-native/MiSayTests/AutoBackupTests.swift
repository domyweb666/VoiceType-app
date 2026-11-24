@testable import MiSay
import XCTest

/// 2026-11-24 自動備份的判斷與檔案。選資料夾、書籤只有真機驗得到。
final class AutoBackupTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var folder = FileManager.default.temporaryDirectory

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    func test一天最多一次照行事曆算() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Taipei"))
        let morning = calendar.startOfDay(for: now).addingTimeInterval(60)
        let night = morning.addingTimeInterval(23 * 60 * 60)
        let nextDay = morning.addingTimeInterval(24 * 60 * 60)
        XCTAssertTrue(AutoBackup.isDue(lastWrittenAt: nil, now: now, calendar: calendar))
        XCTAssertFalse(AutoBackup.isDue(lastWrittenAt: morning, now: night, calendar: calendar))
        XCTAssertTrue(AutoBackup.isDue(lastWrittenAt: night, now: nextDay, calendar: calendar))
    }

    func test內容有變指紋才變_順序不算() throws {
        let first = Transcript(durationSeconds: 10, rawText: "一")
        let second = Transcript(durationSeconds: 10, rawText: "二")
        let fingerprint = try AutoBackup.fingerprint(of: [first, second])
        XCTAssertEqual(try AutoBackup.fingerprint(of: [second, first]), fingerprint)
        var changed = first
        changed.draftText = "改過"
        XCTAssertNotEqual(try AutoBackup.fingerprint(of: [changed, second]), fingerprint)
    }

    func test只留最近七份_有讀不到的篇就一份都不刪() {
        let names = (1 ... 9).map { "第\($0)份" }
        let pruned = AutoBackup.filesToKeep(names, prunes: true)
        XCTAssertEqual(pruned.kept, Array(names.suffix(7)))
        XCTAssertEqual(pruned.doomed, ["第1份", "第2份"])
        let untouched = AutoBackup.filesToKeep(names, prunes: false)
        XCTAssertEqual(untouched.kept, names)
        XCTAssertEqual(untouched.doomed, [])
    }

    func test寫出去的讀得回來_同一分鐘不蓋掉前一份() throws {
        let transcript = Transcript(durationSeconds: 10, rawText: "口語")
        let data = try Backup(transcripts: [transcript], exportedAt: now).encoded()
        let first = try AutoBackupFolder.write(data, to: folder, at: now)
        let second = try AutoBackupFolder.write(data, to: folder, at: now)
        XCTAssertNotEqual(first, second)
        let written = try Data(contentsOf: folder.appending(path: first))
        XCTAssertEqual(try Backup.decode(written).transcripts, [transcript])

        AutoBackupFolder.delete([first], in: folder)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertEqual(remaining, [second])
    }

    func test寫不進去說寫不進去() {
        let missing = folder.appending(path: "沒有這個資料夾")
        XCTAssertThrowsError(
            try AutoBackupFolder.write(Data(), to: missing, at: now)
        ) { error in
            XCTAssertEqual(error as? AutoBackup.Failure, .cannotWrite)
        }
    }

    func test上次備份取近的那一次() {
        XCTAssertNil(BackupHistory.latest(
            exportedSeconds: BackupHistory.neverExported,
            autoWrittenAt: nil
        ))
        let later = now.addingTimeInterval(60)
        XCTAssertEqual(
            BackupHistory.latest(
                exportedSeconds: now.timeIntervalSince1970,
                autoWrittenAt: later
            ),
            later
        )
        XCTAssertEqual(
            BackupHistory.latest(exportedSeconds: now.timeIntervalSince1970, autoWrittenAt: nil),
            now
        )
    }

    @MainActor
    func test沒打開就不跑_打開的狀態存得住() async throws {
        let name = "AutoBackupTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        let autoBackup = AutoBackup(defaults: defaults)
        XCTAssertFalse(autoBackup.isOn)
        await autoBackup.runIfDue(now: now)
        XCTAssertNil(autoBackup.lastFailure)

        // 打開了卻沒有資料夾：記下來讓人看到，不默默跳過。
        autoBackup.setOn(true)
        await autoBackup.runIfDue(now: now)
        XCTAssertEqual(autoBackup.lastFailure, .folderMissing)
        let reopened = AutoBackup(defaults: defaults)
        XCTAssertTrue(reopened.isOn)
        XCTAssertEqual(reopened.lastFailure, .folderMissing)
    }
}
