@testable import MiSay
import XCTest

/// 組塊 S 片 S6：診斷紀錄寫得進去、會換份、匯出看得到。內容不准有金鑰與文字稿靠呼叫端，這裡只測機制。
final class DiagnosticLogTests: XCTestCase {
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func test診斷紀錄一行一筆而且照順序() {
        let log = DiagnosticLog(directory: directory)
        log.record("第一筆")
        log.record("第二筆")
        let lines = log.exportedText().split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasSuffix(" 第一筆"))
        XCTAssertTrue(lines[1].hasSuffix(" 第二筆"))
    }

    func test診斷紀錄超過大小換一份匯出時舊的在前面() {
        let log = DiagnosticLog(directory: directory, maxBytes: 64)
        let filler = String(repeating: "x", count: 80)
        log.record("舊的\(filler)")
        log.record("新的")
        let text = log.exportedText()
        let oldRange = text.range(of: "舊的")
        let newRange = text.range(of: "新的")
        XCTAssertNotNil(oldRange)
        XCTAssertNotNil(newRange)
        if let oldRange, let newRange {
            XCTAssertLessThan(oldRange.lowerBound, newRange.lowerBound)
        }
    }

    func test診斷紀錄只留兩份不會一直長() throws {
        let log = DiagnosticLog(directory: directory, maxBytes: 16)
        for index in 0 ..< 10 {
            log.record("第 \(index) 筆內容內容內容內容")
        }
        let text = log.exportedText()
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(files.count, 2)
        XCTAssertFalse(text.contains("第 0 筆"), "最舊的應該被換掉了")
        XCTAssertTrue(text.contains("第 9 筆"))
    }

    func test診斷紀錄沒有資料夾也不會出事() {
        let log = DiagnosticLog(directory: nil)
        log.record("寫不進去")
        XCTAssertEqual(log.exportedText(), "")
    }
}
