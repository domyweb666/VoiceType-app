import Foundation
import os

/// 方塊 M12：出事時查得到發生什麼。只記時間、事件、數字。
/// 金鑰、錄音內容、口語稿、文字稿一律不准傳進來（規矩檔第 3 節）；只有使用者自己按分享才離開手機。
/// 寫不進去只記一筆系統 log：這份紀錄壞掉不能影響錄音和整理。
final class DiagnosticLog {
    static let shared = DiagnosticLog(directory: DiagnosticLog.defaultDirectory())
    /// 超過這個大小就換一份，只留上一份：一行幾十個字，夠記很多次長錄音。
    static let maxFileBytes = 1_000_000
    private static let currentName = "diagnostics.log"
    private static let previousName = "diagnostics.previous.log"
    private static let logger = Logger(subsystem: "MiSay", category: "DiagnosticLog")
    /// 第一次解鎖後可用：鎖屏時還在錄，紀錄要寫得進去。
    private static let fileProtection = FileProtectionType.completeUntilFirstUserAuthentication

    private let directory: URL?
    private let maxBytes: Int
    private let queue = DispatchQueue(label: "org.domyweb.misay.diagnostics")
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    init(directory: URL?, maxBytes: Int = DiagnosticLog.maxFileBytes) {
        self.directory = directory
        self.maxBytes = maxBytes
    }

    /// 排進背景佇列就回來，誰都可以叫，不會卡住錄音。
    func record(_ event: String) {
        let now = Date()
        queue.async { [self] in
            append("\(timestampFormatter.string(from: now)) \(event)\n")
        }
    }

    /// 匯出用：上一份接這一份，舊的在前面。
    func exportedText() -> String {
        queue.sync {
            guard let directory else {
                return ""
            }
            return [Self.previousName, Self.currentName]
                .compactMap {
                    try? String(contentsOf: directory.appending(path: $0), encoding: .utf8)
                }
                .joined()
        }
    }

    private func append(_ line: String) {
        guard let directory else {
            return
        }
        let url = directory.appending(path: Self.currentName)
        do {
            try rotateIfNeeded(url, in: directory)
            guard FileManager.default.fileExists(atPath: url.path) else {
                try Data(line.utf8).write(to: url, options: .atomic)
                return
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } catch {
            Self.logger.error("診斷紀錄寫不進去")
        }
    }

    private func rotateIfNeeded(_ url: URL, in directory: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size >= maxBytes else {
            return
        }
        let previous = directory.appending(path: Self.previousName)
        if fileManager.fileExists(atPath: previous.path) {
            try fileManager.removeItem(at: previous)
        }
        try fileManager.moveItem(at: url, to: previous)
    }

    /// 資料夾建不起來就不記（`directory` 是 nil），App 照常。
    private static func defaultDirectory() -> URL? {
        let fileManager = FileManager.default
        do {
            let base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = base.appending(path: "Diagnostics", directoryHint: .isDirectory)
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: fileProtection]
            )
            return directory
        } catch {
            logger.error("診斷紀錄資料夾建不起來")
            return nil
        }
    }
}
