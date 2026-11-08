@testable import MiSay
import XCTest

/// 片 S4-2：上傳前壓成 m4a。只量「壓得出來、小很多、是 m4a」；聽起來準不準要真的轉錄才知道。
final class AudioCompressorTests: XCTestCase {
    func test壓縮十秒的WAV變成小很多的m4a() throws {
        var wav = WAVFileWriter.header(dataByteCount: UInt32(10 * 32000))
        wav.append(Data(repeating: 0x40, count: 10 * 32000))
        let m4a = try XCTUnwrap(AudioCompressor.m4a(fromWAV: wav), "模擬器上應該壓得出來")
        XCTAssertLessThan(m4a.count, wav.count / 4)
        XCTAssertEqual(String(data: m4a.subdata(in: 4 ..< 8), encoding: .ascii), "ftyp")
    }
}
