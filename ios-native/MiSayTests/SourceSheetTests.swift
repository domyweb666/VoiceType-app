@testable import MiSay
import XCTest

/// Y6「錄音與原稿」：沒有的看法不出現，重新轉錄的條件照舊。
final class SourceSheetTests: XCTestCase {
    func test有文字稿又有錄音_三種都有() {
        let transcript = Transcript(durationSeconds: 10, rawText: "口語", draftText: "文字稿")
        XCTAssertEqual(
            SourceSheet.modes(for: transcript, hasRecording: true),
            [.raw, .diff, .audio]
        )
        XCTAssertEqual(SourceSheet.modes(for: transcript, hasRecording: false), [.raw, .diff])
    }

    func test錄音刪了但標過重點_還是有聽原音與重點() {
        var transcript = Transcript(durationSeconds: 10, rawText: "口語", draftText: "文字稿")
        transcript.marks = [3]
        XCTAssertEqual(
            SourceSheet.modes(for: transcript, hasRecording: false),
            [.raw, .diff, .audio]
        )
    }

    func test還沒整理的只有錄音_自己打的什麼都沒有() {
        let unpolished = Transcript(durationSeconds: 10, rawText: "口語")
        XCTAssertEqual(SourceSheet.modes(for: unpolished, hasRecording: true), [.audio])
        XCTAssertEqual(SourceSheet.modes(for: .blankDraft(), hasRecording: false), [])
    }

    func test錄音不在_接著錄過都不給重轉() {
        var transcript = Transcript(durationSeconds: 10, rawText: "口語", draftText: "文字稿")
        XCTAssertTrue(SourceSheet.canRetranscribe(transcript, hasRecording: true))
        XCTAssertFalse(SourceSheet.canRetranscribe(transcript, hasRecording: false))
        transcript.combinedAt = Date()
        XCTAssertFalse(SourceSheet.canRetranscribe(transcript, hasRecording: true))
    }
}
