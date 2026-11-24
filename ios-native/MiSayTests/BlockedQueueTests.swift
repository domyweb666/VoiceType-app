@testable import MiSay
import XCTest

/// 2026-11-25 審查：整理流水碰到進度檔、存檔一時讀不到，不花錢、不蓋、不擋別筆。
/// 只准在模擬器跑：會存金鑰、清掉文字稿資料夾、寫進待轉錄。
@MainActor
final class BlockedQueueTests: XCTestCase {
    private let keyStore = APIKeyStore()
    private let store = TranscriptStore()
    private let suiteName = "BlockedQueueTests"
    private var recordings: [URL] = []

    override func setUp() async throws {
        try keyStore.save("sk-test-假金鑰-讀不到用")
        FakeOpenAIServer.reset()
        UserDefaults().removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: store.directoryURL())
        recordings = []
    }

    override func tearDown() async throws {
        try keyStore.delete()
        FakeOpenAIServer.reset()
        UserDefaults().removePersistentDomain(forName: suiteName)
        for recording in recordings {
            let progress = RecordingTranscriptionJob.progressURL(for: recording)
            try? FileManager.default.removeItem(at: progress)
            try? FileManager.default.removeItem(at: recording)
        }
        for transcript in (try? store.loadAll().transcripts) ?? [] {
            try? FileManager.default.removeItem(at: RetainedRecordings().url(for: transcript.id))
        }
        try? FileManager.default.removeItem(at: store.directoryURL())
    }

    func test進度讀不到是獨立結局_不送不蓋進度檔() async throws {
        let recording = try makeRecording(minutesAgo: 0)
        let progress = RecordingTranscriptionJob.progressURL(for: recording)
        try RecordingTranscriptionJob().saveProgress(.init(), for: recording)
        let bytes = try Data(contentsOf: progress)
        try setPermissions(0, of: progress)

        let outcome = try await makeQueue().process(recordingAt: recording)
        XCTAssertEqual(outcome, .progressUnreadable)
        XCTAssertEqual(FakeOpenAIServer.requestCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recording.path))
        try setPermissions(0o600, of: progress)
        XCTAssertEqual(try Data(contentsOf: progress), bytes)
    }

    func test續轉跳過進度讀不到的那筆_更新的照樣整理() async throws {
        let blocked = try makeRecording(minutesAgo: 60)
        let newer = try makeRecording(minutesAgo: 1)
        let progress = RecordingTranscriptionJob.progressURL(for: blocked)
        try RecordingTranscriptionJob().saveProgress(.init(), for: blocked)
        try setPermissions(0, of: progress)
        FakeOpenAIServer.queuedReplies = [
            .http(status: 200, body: #"{"text":"口語稿。"}"#),
            .http(status: 200, body: chat("草稿。")),
        ]
        // 別的測試留下的錄音不送，只看這兩筆。
        let mine = Set([blocked, newer].map(\.lastPathComponent))
        let queue = try makeQueue()
        queue.refusedRecordings = try Set(PendingRecordings().list().map(\.id)).subtracting(mine)
        let refusedBefore = queue.refusedRecordings

        await queue.processPending()
        XCTAssertTrue(FileManager.default.fileExists(atPath: blocked.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: newer.path))
        XCTAssertEqual(try store.loadAll().transcripts.map(\.draftText), ["草稿。"])
        XCTAssertEqual(queue.refusedRecordings, refusedBefore, "讀不到的不標紅字，下一輪再試")
    }

    func test接回去時存檔一時讀不到_先等_下一輪才接() throws {
        let target = Transcript(durationSeconds: 60, rawText: "口語", draftText: "第一段。")
        let added = Transcript(durationSeconds: 30, rawText: "口語補", draftText: "補的。")
        try store.save(target)
        try store.save(added)
        let queue = TranscriptionQueue()
        queue.appendTargetsByTranscript[added.id] = TranscriptionQueue.AppendTarget(
            transcriptID: target.id,
            insertion: nil
        )
        let file = try store.fileURL(for: target.id)
        try setPermissions(0, of: file)
        defer { try? setPermissions(0o600, of: file) }

        XCTAssertEqual(queue.mergeIntoAppendTarget(added).id, added.id)
        XCTAssertTrue(queue.isWaitingToAppend(added.id))
        queue.retryWaitingAppends()
        XCTAssertTrue(queue.isWaitingToAppend(added.id))
        XCTAssertEqual(try store.load(id: added.id)?.draftText, "補的。")

        try setPermissions(0o600, of: file)
        queue.retryWaitingAppends()
        XCTAssertFalse(queue.isWaitingToAppend(added.id))
        XCTAssertEqual(try store.load(id: target.id)?.draftText, "第一段。\n\n補的。")
        XCTAssertNil(try store.load(id: added.id))
    }

    func test潤飾前存檔一時讀不到_不送也不蓋() async throws {
        var newer = Transcript(durationSeconds: 60, rawText: "口語")
        let held = newer
        newer.rawText = "口語加新錄的"
        try store.save(newer)
        let file = try store.fileURL(for: newer.id)
        try setPermissions(0, of: file)
        defer { try? setPermissions(0o600, of: file) }

        let queue = try makeQueue()
        let outcome = await queue.retryPolish(held)
        guard case let .polishFailed(kept, _) = outcome else {
            return XCTFail("應該先不潤飾，拿到 \(String(describing: outcome))")
        }
        XCTAssertEqual(kept.id, held.id)
        XCTAssertEqual(FakeOpenAIServer.requestCount, 0)
        try setPermissions(0o600, of: file)
        XCTAssertEqual(try store.load(id: newer.id)?.rawText, "口語加新錄的")
    }

    private func chat(_ content: String) -> String {
        #"{"choices":[{"message":{"role":"assistant","content":""# + content
            + #""},"finish_reason":"stop"}]}"#
    }

    private func makeQueue() throws -> TranscriptionQueue {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeOpenAIServer.self]
        let client = OpenAIClient(session: URLSession(configuration: configuration))
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        return TranscriptionQueue(
            transcriber: Transcriber(client: client, retryBaseDelaySeconds: 0.01),
            polisher: Polisher(client: client, retryBaseDelaySeconds: 0.01),
            settings: AppSettings(defaults: defaults)
        )
    }

    /// 放進待轉錄的一分鐘靜音：不到一段，整筆只送一次轉錄。
    private func makeRecording(minutesAgo: Double) throws -> URL {
        let url = try PendingRecordings().directoryURL()
            .appending(path: "rec-\(UUID().uuidString).wav")
        recordings.append(url)
        var writer = try WAVFileWriter(creatingAt: url)
        try writer.append(pcm: Data(repeating: 0, count: 60 * 32000))
        try writer.finish()
        try FileManager.default.setAttributes(
            [.creationDate: Date().addingTimeInterval(-minutesAgo * 60)],
            ofItemAtPath: url.path
        )
        return url
    }

    private func setPermissions(_ mode: Int, of file: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: file.path)
    }
}
