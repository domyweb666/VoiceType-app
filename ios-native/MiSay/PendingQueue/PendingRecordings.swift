import Foundation
import os

/// 方塊 M2 的待轉錄資料夾：收錄音檔（C1）、重開時撿回救回檔（C4）、列出與刪掉（C6）。
/// 判斷條件、自動續轉、失敗就停是 D5。
/// 資料夾在 App 自己的 Application Support 裡，開檔案保護（安全標準二）。
struct PendingRecordings {
    enum Failure: Error, Equatable {
        case cannotCreateDirectory
        case cannotMoveIn
        case cannotList
        case cannotDelete
    }

    /// 待轉錄清單的一列：時間從檔案建立時間來、長度從檔案大小算，不另外存索引。
    struct Recording: Identifiable, Equatable {
        let url: URL
        let recordedAt: Date
        let durationSeconds: Double

        var id: String { url.lastPathComponent }
    }

    /// 只記檔名（時間戳，不含內容），規矩檔第 3 節。
    private static let logger = Logger(subsystem: "MiSay", category: "PendingRecordings")
    private let fileManager = FileManager.default

    /// 資料夾不存在就建；每次都把保護等級設一次，舊資料夾也會被補上。
    func directoryURL() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(path: "Pending", directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: Recorder.fileProtection]
            )
            try fileManager.setAttributes(
                [.protectionKey: Recorder.fileProtection],
                ofItemAtPath: directory.path
            )
        } catch {
            throw Failure.cannotCreateDirectory
        }
        return directory
    }

    /// 把錄好的檔搬進來（同一個 volume 是改名，不是複製）。回搬進來之後的位置。
    func accept(recordingAt source: URL) throws -> URL {
        let destination = try directoryURL().appending(path: source.lastPathComponent)
        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            throw Failure.cannotMoveIn
        }
        return destination
    }

    /// 片 C4：重開時把錄到一半被殺掉的檔撿回來：補檔頭、搬進待轉錄。
    /// 一個 byte 都沒錄到的空檔直接丟（它從沒裝過資料）。只准在開始任何錄音之前呼叫。
    func recoverAbandonedRecordings() throws -> [URL] {
        let abandonedDirectory = try Recorder.inProgressDirectoryURL()
        let files: [URL]
        do {
            files = try fileManager.contentsOfDirectory(
                at: abandonedDirectory,
                includingPropertiesForKeys: nil
            )
        } catch {
            throw Failure.cannotList
        }
        var recovered: [URL] = []
        for file in files where file.pathExtension == "wav" {
            // 一個檔撿不回來不擋其他檔：它留在原地（資料沒動），下次重開再試，並記一筆。
            do {
                let dataByteCount = try WAVFileWriter.repairHeader(at: file)
                if dataByteCount == 0 {
                    try fileManager.removeItem(at: file)
                    continue
                }
                try recovered.append(accept(recordingAt: file))
            } catch {
                Self.logger.error("救回檔撿不回來，留在原地：\(file.lastPathComponent, privacy: .public)")
            }
        }
        return recovered
    }

    /// 片 C6：最新的在最上面。
    func list() throws -> [Recording] {
        let directory = try directoryURL()
        let keys: [URLResourceKey] = [.creationDateKey, .fileSizeKey]
        let files: [URL]
        do {
            files = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys
            )
        } catch {
            throw Failure.cannotList
        }
        let bytesPerFrame = WAVFileWriter.channelCount * WAVFileWriter.bitsPerSample / 8
        let bytesPerSecond = Double(WAVFileWriter.sampleRate * bytesPerFrame)
        let recordings = files.filter { $0.pathExtension == "wav" }.map { file -> Recording in
            let values = try? file.resourceValues(forKeys: Set(keys))
            let size = Double(values?.fileSize ?? WAVFileWriter.headerByteCount)
            let seconds = max(0, size - Double(WAVFileWriter.headerByteCount)) / bytesPerSecond
            return Recording(
                url: file,
                recordedAt: values?.creationDate ?? .distantPast,
                durationSeconds: seconds
            )
        }
        return recordings.sorted { $0.recordedAt > $1.recordedAt }
    }

    /// 片 C6「刪掉這一個」。畫面要先用系統動作表確認過才准呼叫（⚠️ 刪檔）。
    func delete(_ recording: Recording) throws {
        try delete(recordingAt: recording.url)
    }

    /// D5：口語稿存進歷史之後由流水呼叫；畫面上的刪除走上面那個。
    func delete(recordingAt url: URL) throws {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw Failure.cannotDelete
        }
    }
}
