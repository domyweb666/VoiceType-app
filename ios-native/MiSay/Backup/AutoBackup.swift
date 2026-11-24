import CryptoKit
import Foundation
import Observation

/// 自動備份到資料夾（2026-11-24）：預設關，使用者自己選資料夾。回到前景時看一次，
/// 一天最多寫一份、內容有變才寫、只留自己寫的最近 7 份。沒成功就記下來，備份區看得到。
/// 設定與紀錄不是秘密，放 UserDefaults；裡面沒有文字稿，內容有沒有變只存雜湊。
@MainActor
@Observable
final class AutoBackup {
    enum Failure: String, Error {
        case folderMissing
        case cannotAccess
        case cannotWrite
        case cannotRead

        var message: String {
            switch self {
            case .folderMissing: "自動備份沒成功：找不到那個資料夾，換一個資料夾。"
            case .cannotAccess: "自動備份沒成功：進不去那個資料夾，換一個資料夾。"
            case .cannotWrite: "自動備份沒成功：寫不進去，看看那個資料夾的空間。"
            case .cannotRead: "自動備份沒成功：手機上的文字稿讀不到。"
            }
        }
    }

    static let shared = AutoBackup()
    nonisolated static let keptFileCount = 7

    private enum Key {
        static let isOn = "autoBackupIsOn"
        static let bookmark = "autoBackupBookmark"
        static let folderName = "autoBackupFolderName"
        static let lastWrittenAt = "autoBackupLastWrittenAt"
        static let fingerprint = "autoBackupFingerprint"
        static let writtenFiles = "autoBackupWrittenFiles"
        static let lastFailure = "autoBackupLastFailure"
    }

    private(set) var isOn: Bool
    private(set) var folderName: String?
    private(set) var lastWrittenAt: Date?
    private(set) var lastFailure: Failure?
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOn = defaults.bool(forKey: Key.isOn)
        folderName = defaults.string(forKey: Key.folderName)
        lastWrittenAt = defaults.object(forKey: Key.lastWrittenAt) as? Date
        lastFailure = defaults.string(forKey: Key.lastFailure).flatMap(Failure.init(rawValue:))
    }

    func setOn(_ newValue: Bool) {
        isOn = newValue
        defaults.set(newValue, forKey: Key.isOn)
        record(nil)
    }

    /// 選好資料夾就打開。換了資料夾要從頭寫一份；舊資料夾裡的檔留著，不歸這裡管了。
    func use(folder: URL) throws {
        let bookmark = try AutoBackupFolder.bookmark(for: folder)
        defaults.set(bookmark, forKey: Key.bookmark)
        defaults.set(folder.lastPathComponent, forKey: Key.folderName)
        folderName = folder.lastPathComponent
        forgetWrittenFiles()
        setOn(true)
    }

    /// 忘掉寫過哪些檔：那些檔留在資料夾裡，之後不會被當成舊備份刪掉。
    func forgetWrittenFiles() {
        defaults.removeObject(forKey: Key.writtenFiles)
        defaults.removeObject(forKey: Key.fingerprint)
        defaults.removeObject(forKey: Key.lastWrittenAt)
        lastWrittenAt = nil
    }

    /// 讀文字稿在主執行緒（跟清單同一條，不會跟刪除、放回交錯）；組檔、寫檔放背景。
    func runIfDue(now: Date = Date()) async {
        guard isOn, !isRunning, Self.isDue(lastWrittenAt: lastWrittenAt, now: now) else {
            return
        }
        guard let bookmark = defaults.data(forKey: Key.bookmark) else {
            record(.folderMissing)
            return
        }
        guard let loaded = try? TranscriptStore().loadAll() else {
            record(.cannotRead)
            return
        }
        // 一篇都沒有時不寫空的備份。
        guard !loaded.transcripts.isEmpty else {
            return
        }
        isRunning = true
        defer { isRunning = false }
        let job = Job(
            bookmark: bookmark,
            transcripts: loaded.transcripts,
            // 有篇讀不到時這份不完整，舊的備份一份都不刪。
            prunesOldFiles: loaded.unreadableCount == 0,
            previousFingerprint: defaults.string(forKey: Key.fingerprint),
            writtenFiles: defaults.stringArray(forKey: Key.writtenFiles) ?? [],
            now: now
        )
        do {
            let result = try await Task.detached(priority: .utility) { try job.run() }.value
            // 寫的時候使用者換了資料夾：這次的結果是舊資料夾的，不記。
            guard defaults.data(forKey: Key.bookmark) == bookmark else {
                return
            }
            finish(result, now: now)
        } catch {
            record(error as? Failure ?? .cannotWrite)
        }
    }

    private func finish(_ result: JobResult?, now: Date) {
        record(nil)
        guard let result else {
            return
        }
        if let newBookmark = result.renewedBookmark {
            defaults.set(newBookmark, forKey: Key.bookmark)
        }
        defaults.set(result.fingerprint, forKey: Key.fingerprint)
        defaults.set(result.writtenFiles, forKey: Key.writtenFiles)
        defaults.set(now, forKey: Key.lastWrittenAt)
        lastWrittenAt = now
    }

    private func record(_ failure: Failure?) {
        lastFailure = failure
        defaults.set(failure?.rawValue, forKey: Key.lastFailure)
    }

    /// 一天最多一份：照行事曆的同一天算。
    nonisolated static func isDue(
        lastWrittenAt: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        lastWrittenAt.map { !calendar.isDate($0, inSameDayAs: now) } ?? true
    }

    /// 內容有沒有變：不看備份的時間、不看篇的順序。
    nonisolated static func fingerprint(of transcripts: [Transcript]) throws -> String {
        let ordered = transcripts.sorted { $0.id.uuidString < $1.id.uuidString }
        let fixedDate = Date(timeIntervalSince1970: 0)
        let data = try Backup(transcripts: ordered, exportedAt: fixedDate).encoded()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 寫好這一份之後，留哪幾份、刪哪幾份。只算自己寫過的檔，舊的在前。
    nonisolated static func filesToKeep(
        _ writtenFiles: [String],
        prunes: Bool
    ) -> (kept: [String], doomed: [String]) {
        guard prunes else {
            return (writtenFiles, [])
        }
        return (
            Array(writtenFiles.suffix(keptFileCount)),
            Array(writtenFiles.dropLast(keptFileCount))
        )
    }

    private struct JobResult {
        let fingerprint: String
        let writtenFiles: [String]
        let renewedBookmark: Data?
    }

    private struct Job {
        let bookmark: Data
        let transcripts: [Transcript]
        let prunesOldFiles: Bool
        let previousFingerprint: String?
        let writtenFiles: [String]
        let now: Date

        /// 回 nil 是內容沒變，不用寫。寫成功才刪舊的。
        func run() throws -> JobResult? {
            let fingerprint = try AutoBackup.fingerprint(of: transcripts)
            guard fingerprint != previousFingerprint else {
                return nil
            }
            let folder = try AutoBackupFolder(bookmark: bookmark)
            let data = try Backup(transcripts: transcripts, exportedAt: now).encoded()
            return try folder.withAccess { url in
                let name = try AutoBackupFolder.write(data, to: url, at: now)
                let files = AutoBackup.filesToKeep(writtenFiles + [name], prunes: prunesOldFiles)
                AutoBackupFolder.delete(files.doomed, in: url)
                return JobResult(
                    fingerprint: fingerprint,
                    writtenFiles: files.kept,
                    renewedBookmark: folder.renewedBookmark()
                )
            }
        }
    }
}
