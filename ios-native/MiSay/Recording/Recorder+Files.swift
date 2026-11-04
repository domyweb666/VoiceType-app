import Foundation

extension Recorder {
    /// 錄音中的檔先放這裡（救回檔的家，C4 在重開時來撿）；停止後呼叫端搬去待轉錄。
    static func inProgressDirectoryURL() throws -> URL {
        let fileManager = FileManager.default
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(path: "Recording", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: fileProtection]
        )
        return directory
    }

    static func newFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date()) + ".wav"
    }
}
