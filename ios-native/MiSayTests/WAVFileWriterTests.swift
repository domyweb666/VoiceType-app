@testable import MiSay
import XCTest

/// 片 C1：邊錄邊寫的 WAV 檔。檔頭的數字米看不到，這裡鎖死；C4 的救回要靠「被殺掉時長度欄是 0」這件事。
final class WAVFileWriterTests: XCTestCase {
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func test錄音檔頭是16kHz單聲道16bit() throws {
        let url = directory.appending(path: "a.wav")
        let writer = try WAVFileWriter(creatingAt: url)
        try writer.finish()

        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(bytes.count, WAVFileWriter.headerByteCount)
        XCTAssertEqual(Array(bytes[0 ..< 4]), Array("RIFF".utf8))
        XCTAssertEqual(Array(bytes[8 ..< 12]), Array("WAVE".utf8))
        XCTAssertEqual(bytes.littleEndianUInt16(at: 22), 1) // 單聲道
        XCTAssertEqual(bytes.littleEndianUInt32(at: 24), 16000) // 取樣率
        XCTAssertEqual(bytes.littleEndianUInt16(at: 34), 16) // 位元深度
    }

    func test錄音寫一秒後檔頭長度對得上資料() throws {
        let url = directory.appending(path: "b.wav")
        var writer = try WAVFileWriter(creatingAt: url)
        let oneSecond = Data(repeating: 0x7F, count: 32000) // 16000 × 2 bytes
        try writer.append(pcm: oneSecond)
        XCTAssertEqual(writer.elapsedSeconds, 1, accuracy: 0.001)
        try writer.finish()

        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(bytes.count, 44 + 32000)
        XCTAssertEqual(bytes.littleEndianUInt32(at: 4), 36 + 32000)
        XCTAssertEqual(bytes.littleEndianUInt32(at: 40), 32000)
    }

    func test錄音被殺掉前資料已落地但檔頭長度是0() throws {
        // 不呼叫 finish，模擬 App 被系統殺掉：資料在、檔頭長度欄還是 0，C4 就是靠這個判斷要修。
        let url = directory.appending(path: "c.wav")
        var writer = try WAVFileWriter(creatingAt: url)
        try writer.append(pcm: Data(repeating: 1, count: 3200))

        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(bytes.count, 44 + 3200)
        XCTAssertEqual(bytes.littleEndianUInt32(at: 40), 0)
    }
}

extension Data {
    func littleEndianUInt32(at offset: Int) -> UInt32 {
        var value: UInt32 = 0
        for index in 0 ..< 4 {
            value |= UInt32(self[offset + index]) << (8 * UInt32(index))
        }
        return value
    }

    func littleEndianUInt16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
}
