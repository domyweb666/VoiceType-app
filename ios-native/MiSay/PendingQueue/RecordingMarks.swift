import Foundation

/// K6 錄音中標的重點：第幾秒。存在待轉錄資料夾裡、錄音檔旁邊（`<檔名>.marks.json`），
/// App 被殺也還在；口語稿存進歷史時搬進那一篇，這個檔就刪。只有秒數，沒有講過的話。
struct RecordingMarks {
    static let fileExtension = "marks.json"

    /// 錄音中按「標記」時叫：`recordingName` 是錄音檔名，停止後它用同一個名字搬進待轉錄。
    func add(_ seconds: Double, forRecordingNamed recordingName: String) throws {
        let url = try fileURL(forRecordingNamed: recordingName)
        var marks = load(at: url)
        marks.append(seconds)
        try JSONEncoder().encode(marks).write(to: url, options: .atomic)
    }

    func load(forRecordingAt recordingURL: URL) -> [Double] {
        load(at: Self.fileURL(next: recordingURL))
    }

    func delete(forRecordingAt recordingURL: URL) {
        // 沒有標過就沒有這個檔，刪不到不算錯。
        try? FileManager.default.removeItem(at: Self.fileURL(next: recordingURL))
    }

    static func fileURL(next recordingURL: URL) -> URL {
        recordingURL.deletingPathExtension().appendingPathExtension(fileExtension)
    }

    private func fileURL(forRecordingNamed name: String) throws -> URL {
        try Self.fileURL(next: PendingRecordings().directoryURL().appending(path: name))
    }

    private func load(at url: URL) -> [Double] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
        return ((try? JSONDecoder().decode([Double].self, from: data)) ?? []).sorted()
    }
}
