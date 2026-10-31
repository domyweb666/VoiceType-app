import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// 方塊 M8：全部文字稿打包成一個 JSON 檔（片 G1），再從這種檔合併回來（片 G2）。
/// 檔裡只有文字稿，沒有金鑰（安全標準二）；新手機要重貼金鑰。
/// 備份檔沒有加密：換手機時舊手機 Keychain 的加密金鑰帶不過去，加密了新手機也解不開。畫面要講清楚。
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

    /// 只解開頭兩欄，用來分辨「不是米說的檔」和「米說的檔但壞了」。
    private struct Header: Decodable {
        let app: String
        let version: Int
    }
}

/// 給 ShareLink 用：按下分享才讀歷史、組檔，不是一進設定頁就把全部文字稿抱在記憶體。
struct BackupFile: Transferable {
    static let fileName = "米說備份.json"

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { _ in
            let transcripts = try TranscriptStore().loadAll().transcripts
            let url = FileManager.default.temporaryDirectory.appending(path: fileName)
            let data = try Backup(transcripts: transcripts).encoded()
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return SentTransferredFile(url)
        }
    }
}
