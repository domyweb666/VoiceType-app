@testable import MiSay
import XCTest

/// 2026-11-08 加的「原稿」：潤飾成功時跟文字稿一起寫進去，之後改字只動文字稿；舊檔沒有這欄照樣讀得出來。
final class TranscriptOriginalDraftTests: XCTestCase {
    func test潤飾成功時原稿與文字稿一起寫入() {
        var transcript = Transcript(durationSeconds: 10, rawText: "口語")
        transcript.applyPolish("文字稿。", model: "m", style: .keepVoice)

        XCTAssertEqual(transcript.draftText, "文字稿。")
        XCTAssertEqual(transcript.originalDraft, "文字稿。")
        XCTAssertEqual(transcript.polishModel, "m")
        XCTAssertEqual(transcript.polishStyle, PolishStyle.keepVoice.rawValue)

        transcript.draftText = "我改過的文字稿。"
        XCTAssertEqual(transcript.originalDraft, "文字稿。")
    }

    func test舊檔沒有原稿欄也讀得出來() throws {
        let json = """
        {"id":"\(UUID().uuidString)","createdAt":"2026-11-01T00:00:00Z","durationSeconds":3,
        "rawText":"舊的","draftText":"舊的。","updatedAt":"2026-11-01T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let transcript = try decoder.decode(Transcript.self, from: Data(json.utf8))

        XCTAssertEqual(transcript.draftText, "舊的。")
        XCTAssertNil(transcript.originalDraft)
    }
}
