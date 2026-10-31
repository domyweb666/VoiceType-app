import Foundation

/// 方塊 M2 的第一塊磚：待轉錄資料夾。片 C1 只有「建資料夾」與「收一個錄音檔進來」；
/// 判斷條件、自動續轉、失敗就停是 D5。
/// 資料夾在 App 自己的 Application Support 裡，開檔案保護（安全標準二）。
struct PendingRecordings {
    enum Failure: Error, Equatable {
        case cannotCreateDirectory
        case cannotMoveIn
    }

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
}
