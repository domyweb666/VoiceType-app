@testable import MiSay
import XCTest

/// 片 K7：匯入音檔轉成米說自己的 WAV、放進待轉錄。只准在模擬器跑：會寫進 App 的待轉錄資料夾。
final class AudioImportTests: XCTestCase {
    func test匯入m4a轉成十六千赫單聲道WAV放進待轉錄() throws {
        var wav = WAVFileWriter.header(dataByteCount: UInt32(2 * 32000))
        wav.append(Data(repeating: 0x40, count: 2 * 32000))
        let m4a = try XCTUnwrap(AudioCompressor.m4a(fromWAV: wav))
        let source = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("m4a")
        try m4a.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let imported = try AudioImport.importAudio(from: source)
        defer { try? FileManager.default.removeItem(at: imported) }

        XCTAssertEqual(imported.pathExtension, "wav")
        XCTAssertTrue(imported.lastPathComponent.hasPrefix("import-"))
        let size = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: imported.path)[.size] as? NSNumber
        ).intValue
        // AAC 前後會多幾十毫秒，只要大約是兩秒、而且是 16 kHz 單聲道 16-bit 的量。
        XCTAssertGreaterThan(size, 44 + 32000 * 3 / 2)
        XCTAssertLessThan(size, 44 + 32000 * 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "原檔不動")
    }
}
