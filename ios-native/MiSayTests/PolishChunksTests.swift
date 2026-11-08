@testable import MiSay
import XCTest

/// 片 S2-3：口語稿切塊（純函式）與分塊潤飾的續做。
@MainActor
final class PolishChunksTests: XCTestCase {
    func test切塊短稿整篇一塊() {
        XCTAssertEqual(PolishChunks.split("短短一段。"), ["短短一段。"])
        XCTAssertEqual(PolishChunks.split(""), [""])
    }

    func test切塊切在句尾不把一句拆兩塊() {
        let sentence = String(repeating: "字", count: 9) + "。"
        let text = String(repeating: sentence, count: 25)
        let chunks = PolishChunks.split(text, maxCharacters: 105)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 105 })
        XCTAssertTrue(chunks.dropLast().allSatisfy { $0.hasSuffix("。") })
        XCTAssertEqual(chunks.joined(), text, "切完接回去一個字都不少")
    }

    func test切塊整塊沒有句尾就硬切() {
        let text = String(repeating: "字", count: 250)
        let chunks = PolishChunks.split(text, maxCharacters: 100)
        XCTAssertEqual(chunks.map(\.count), [100, 100, 50])
    }

    func test切塊一小時的稿約八塊() {
        let sentence = String(repeating: "講", count: 29) + "。"
        let text = String(repeating: sentence, count: 500)
        XCTAssertEqual(PolishChunks.split(text).count, 8)
    }
}
