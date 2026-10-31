@testable import MiSay
import XCTest

/// 片 G1、G2：備份檔的格式、驗證與合併。選檔、分享表單、真的換手機只有米在真機驗得到。
final class BackupTests: XCTestCase {
    private let first = Transcript(durationSeconds: 120, rawText: "口語稿一", draftText: "文字稿一")
    private let second = Transcript(durationSeconds: 30, rawText: "口語稿二")

    func test備份匯出再匯回來篇數和內容都一樣而且沒有金鑰欄() throws {
        let data = try Backup(transcripts: [first, second]).encoded()
        let restored = try Backup.decode(data)
        XCTAssertEqual(restored.transcripts, [first, second])

        let json = try XCTUnwrap(String(bytes: data, encoding: .utf8))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("apikey"))
        XCTAssertFalse(json.contains("sk-"))
    }

    func test備份合併時手機上已經有的跳過() {
        let backup = Backup(transcripts: [first, second])
        XCTAssertEqual(backup.newTranscripts(existingIDs: [first.id]), [second])
        XCTAssertEqual(backup.newTranscripts(existingIDs: []), [first, second])

        let duplicated = Backup(transcripts: [first, first, second])
        XCTAssertEqual(duplicated.newTranscripts(existingIDs: []), [first, second])
    }

    func test備份不是米說的檔不收() {
        let other = Data(#"{"app":"Other","version":1}"#.utf8)
        XCTAssertThrowsError(try Backup.decode(other)) { error in
            XCTAssertEqual(error as? Backup.Failure, .notABackup)
        }
        XCTAssertThrowsError(try Backup.decode(Data("不是 JSON".utf8))) { error in
            XCTAssertEqual(error as? Backup.Failure, .notABackup)
        }
    }

    func test備份新版做的檔要先更新() {
        let newer = Data(#"{"app":"MiSay","version":99}"#.utf8)
        XCTAssertThrowsError(try Backup.decode(newer)) { error in
            XCTAssertEqual(error as? Backup.Failure, .newerVersion)
        }
    }

    func test備份是米說的檔但裡面壞了說壞了() {
        let broken = Data(#"{"app":"MiSay","version":1,"transcripts":"壞"}"#.utf8)
        XCTAssertThrowsError(try Backup.decode(broken)) { error in
            XCTAssertEqual(error as? Backup.Failure, .unreadable)
        }
    }

    func test備份太大的檔不收() {
        let huge = Data(count: Backup.maxImportBytes + 1)
        XCTAssertThrowsError(try Backup.decode(huge)) { error in
            XCTAssertEqual(error as? Backup.Failure, .tooLarge)
        }
    }
}
