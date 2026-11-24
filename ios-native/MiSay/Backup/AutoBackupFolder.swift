import Foundation

/// 自動備份要寫進去的那個資料夾：用書籤記住、打開、寫一份、刪舊的。檔名帶時間，不蓋掉任何已經在的檔。
struct AutoBackupFolder {
    private static let fileNamePrefix = "米說自動備份 "
    private static let fileExtension = "json"

    let url: URL
    private let isStale: Bool

    init(bookmark: Data) throws {
        var isStale = false
        do {
            url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
        } catch {
            throw AutoBackup.Failure.folderMissing
        }
        self.isStale = isStale
    }

    /// 從「檔案」選回來的資料夾：要先拿到存取權才建得出書籤。
    static func bookmark(for folder: URL) throws -> Data {
        guard folder.startAccessingSecurityScopedResource() else {
            throw AutoBackup.Failure.cannotAccess
        }
        defer { folder.stopAccessingSecurityScopedResource() }
        do {
            return try folder.bookmarkData()
        } catch {
            throw AutoBackup.Failure.cannotAccess
        }
    }

    func withAccess<Value>(_ work: (URL) throws -> Value) throws -> Value {
        guard url.startAccessingSecurityScopedResource() else {
            throw AutoBackup.Failure.cannotAccess
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try work(url)
    }

    /// 資料夾搬過、書籤舊了：趁還打得開換一份新的。換不成就照用舊的，下次再換。
    func renewedBookmark() -> Data? {
        isStale ? try? url.bookmarkData() : nil
    }

    /// 回寫好的檔名。
    static func write(_ data: Data, to folder: URL, at date: Date) throws -> String {
        let file = freeURL(in: folder, at: date)
        do {
            try data.write(to: file, options: .atomic)
        } catch {
            throw AutoBackup.Failure.cannotWrite
        }
        return file.lastPathComponent
    }

    /// 刪不掉的留著：多佔一點空間，不影響新寫好的那份。
    static func delete(_ names: [String], in folder: URL) {
        for name in names {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }

    /// 「米說自動備份 2026-11-24 0930」。檔名不跟語系走，照字排就是照時間排。
    static func baseName(at date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return fileNamePrefix + formatter.string(from: date)
    }

    private static func freeURL(in folder: URL, at date: Date) -> URL {
        let base = baseName(at: date)
        var candidate = folder.appending(path: base).appendingPathExtension(fileExtension)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appending(path: "\(base) (\(number))")
                .appendingPathExtension(fileExtension)
            number += 1
        }
        return candidate
    }
}
