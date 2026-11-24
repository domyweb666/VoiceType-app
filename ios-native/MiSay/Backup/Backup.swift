import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// 方塊 M8：全部文字稿打包成一個 JSON 檔（片 G1），再從這種檔合併回來（片 G2）。
/// 檔裡只有文字稿，沒有金鑰（安全標準二）；新手機要重貼金鑰。
/// 備份檔沒有加密，換到哪支手機都讀得到。畫面要講清楚。
struct Backup: Codable, Equatable {
    enum Failure: Error, Equatable {
        case tooLarge
        case notABackup
        case newerVersion
        case unreadable
    }

    /// 這個檔是誰做的：匯入時先對這個，別人的 JSON 不收。
    static let appIdentifier = "MiSay"
    static let currentVersion = 1
    /// 匯入上限。純文字一千篇也才幾 MB，超過這個多半是選錯檔。
    static let maxImportBytes = 50 * 1024 * 1024

    let app: String
    let version: Int
    let exportedAt: Date
    let transcripts: [Transcript]

    init(transcripts: [Transcript], exportedAt: Date = Date()) {
        app = Self.appIdentifier
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.transcripts = transcripts
    }

    func encoded() throws -> Data {
        // 日期用預設的秒數格式，不用 ISO 8601：後者丟掉小數秒，匯回來時間會差一點點。
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// 先驗大小、再驗是不是米說的檔、再驗版本；每一關擋下來都說是哪一關。
    static func decode(_ data: Data) throws -> Backup {
        guard data.count <= maxImportBytes else {
            throw Failure.tooLarge
        }
        let decoder = JSONDecoder()
        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch {
            throw Failure.notABackup
        }
        guard header.app == appIdentifier, header.version >= 1 else {
            throw Failure.notABackup
        }
        guard header.version <= currentVersion else {
            throw Failure.newerVersion
        }
        do {
            return try decoder.decode(Backup.self, from: data)
        } catch {
            throw Failure.unreadable
        }
    }

    /// 合併不覆蓋（PRD）：同一個 id 已經在手機上的跳過；備份裡自己重複的也只算第一篇，「加入 N 篇」才準。
    func newTranscripts(existingIDs: Set<UUID>) -> [Transcript] {
        var seen = existingIDs
        return transcripts.filter { seen.insert($0.id).inserted }
    }

    /// 備份裡有幾篇在手機的垃圾桶：加進來的話，垃圾桶那份就看不到、到期會刪，所以跳過。
    func trashedCount(trashedIDs: Set<UUID>, listedIDs: Set<UUID>) -> Int {
        Set(transcripts.map(\.id)).intersection(trashedIDs.subtracting(listedIDs)).count
    }

    /// 匯入要存的那份：備份裡不該有垃圾桶的篇，萬一帶著記號也拿掉，加進來就是在清單裡。
    /// 手機垃圾桶裡有同一篇的不會走到這裡（`BackupSection` 跳過、請人先放回）。
    static func importable(_ transcript: Transcript) -> Transcript {
        var imported = transcript
        imported.trashedAt = nil
        return imported
    }

    /// 只解開頭兩欄，用來分辨「不是米說的檔」和「米說的檔但壞了」。
    private struct Header: Decodable {
        let app: String
        let version: Int
    }
}

/// 上次手動匯出時產生備份檔的時間（有沒有存到別處，米說看不到）。備份區用 `@AppStorage` 讀同一個鍵，分享完當場就更新。
struct BackupHistory {
    static let lastExportedKey = "backupLastExportedSeconds"
    /// 從沒匯出過。
    static let neverExported: Double = 0

    var defaults = UserDefaults.standard

    func recordExport(at date: Date = Date()) {
        defaults.set(date.timeIntervalSince1970, forKey: Self.lastExportedKey)
    }

    /// 手動匯出與自動備份，取近的那一次；都沒有是 nil。
    static func latest(exportedSeconds: Double, autoWrittenAt: Date?) -> Date? {
        let exportedAt = exportedSeconds > neverExported
            ? Date(timeIntervalSince1970: exportedSeconds)
            : nil
        return [exportedAt, autoWrittenAt].compactMap { $0 }.max()
    }
}

/// 給 ShareLink 用：按下分享才讀歷史、組檔，不是一進設定頁就把全部文字稿抱在記憶體。
struct BackupFile: Transferable {
    static let fileName = "米說備份.json"

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { _ in
            // 讀文字稿回主執行緒：讀全部會順便換舊檔，不能跟存檔、刪除交錯。
            let transcripts = try await MainActor.run {
                try TranscriptStore().loadAll().transcripts
            }
            let url = FileManager.default.temporaryDirectory.appending(path: fileName)
            let data = try Backup(transcripts: transcripts).encoded()
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            BackupHistory().recordExport()
            return SentTransferredFile(url)
        }
    }
}
