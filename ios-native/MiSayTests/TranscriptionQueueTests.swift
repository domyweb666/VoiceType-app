@testable import MiSay
import XCTest

/// 片 S2-0：整理流水一筆的結局。拆檔前沒有測試，這裡先把五種結局釘住，後面 S2 各片改流水時才知道有沒有改壞。
/// 只准在模擬器跑：會存金鑰、寫進歷史資料夾；每條自己清掉自己存的那一篇。
@MainActor
final class TranscriptionQueueTests: XCTestCase {
    private let keyStore = APIKeyStore()
    private let store = TranscriptStore()
    private let fakeKey = "sk-test-假金鑰-流水用"
    private let suiteName = "TranscriptionQueueTests"
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())
    private var savedIDs: [UUID] = []

    override func setUp() async throws {
        try keyStore.save(fakeKey)
        FakeOpenAIServer.reset()
        UserDefaults().removePersistentDomain(forName: suiteName)
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        savedIDs = []
    }

    override func tearDown() async throws {
        try keyStore.delete()
        FakeOpenAIServer.reset()
        UserDefaults().removePersistentDomain(forName: suiteName)
        for id in savedIDs {
            try? store.delete(id: id)
            if let url = try? RetainedRecordings().url(for: id) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try FileManager.default.removeItem(at: directory)
    }

    func test流水沒有金鑰不送出去() async throws {
        try keyStore.delete()
        let outcome = try await makeQueue().process(recordingAt: makeRecording())
        XCTAssertEqual(outcome, .noAPIKey)
        XCTAssertEqual(FakeOpenAIServer.requestCount, 0)
        try keyStore.save(fakeKey)
    }

    func test流水轉錄被拒錄音檔留著() async throws {
        let recording = try makeRecording()
        FakeOpenAIServer.reply = .http(status: 401, body: "")
        let outcome = try await makeQueue().process(recordingAt: recording)
        XCTAssertEqual(outcome, .transcriptionFailed(.invalidAPIKey(statusCode: 401)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recording.path))
    }

    func test流水讀不到錄音不扣款() async throws {
        let missing = directory.appending(path: "不存在.wav")
        let outcome = try await makeQueue().process(recordingAt: missing)
        XCTAssertEqual(outcome, .recordingUnreadable)
        XCTAssertEqual(FakeOpenAIServer.requestCount, 0)
    }

    func test流水潤飾失敗口語稿已經存進歷史() async throws {
        FakeOpenAIServer.queuedReplies = [
            .http(status: 200, body: #"{"text":"口語稿。"}"#),
            .http(status: 401, body: ""),
        ]
        let outcome = try await makeQueue().process(recordingAt: makeRecording())
        guard case let .polishFailed(transcript, failure) = outcome else {
            return XCTFail("應該是潤飾失敗，拿到 \(String(describing: outcome))")
        }
        savedIDs.append(transcript.id)
        XCTAssertEqual(failure, .invalidAPIKey(statusCode: 401))
        let saved = try store.loadAll().transcripts.first { $0.id == transcript.id }
        XCTAssertEqual(saved?.rawText, "口語稿。")
    }

    func test流水整理完口語稿與草稿都在同一篇() async throws {
        let recording = try makeRecording()
        let draft = #"{"choices":[{"message":{"role":"assistant","content":"草稿。"}}]}"#
        FakeOpenAIServer.queuedReplies = [
            .http(status: 200, body: #"{"text":"口語稿。"}"#),
            .http(status: 200, body: draft),
        ]
        let outcome = try await makeQueue().process(recordingAt: recording)
        guard case let .finished(transcript) = outcome else {
            return XCTFail("應該整理完，拿到 \(String(describing: outcome))")
        }
        savedIDs.append(transcript.id)
        let saved = try XCTUnwrap(store.loadAll().transcripts.first { $0.id == transcript.id })
        XCTAssertEqual(saved.rawText, "口語稿。")
        XCTAssertEqual(saved.draftText, "草稿。")
        XCTAssertNotNil(saved.polishedAt)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recording.path))
        XCTAssertTrue(RetainedRecordings().exists(for: transcript.id), "錄音搬進留存區，不刪（S2-5）")

        FakeOpenAIServer.reset()
        FakeOpenAIServer.queuedReplies = [
            .http(status: 200, body: #"{"text":"重轉的口語稿。"}"#),
            .http(status: 200, body: chat("重轉的草稿。")),
        ]
        let again = try await makeQueue().retranscribe(saved)
        guard case let .finished(redone) = again else {
            return XCTFail("重新轉錄應該整理完，拿到 \(String(describing: again))")
        }
        XCTAssertEqual(redone.id, transcript.id, "存回同一篇")
        XCTAssertEqual(redone.rawText, "重轉的口語稿。")
        XCTAssertEqual(redone.draftText, "重轉的草稿。")
        XCTAssertTrue(RetainedRecordings().exists(for: transcript.id))
    }

    func test流水分塊潤飾第二塊失敗再來只送剩下的塊() async throws {
        let raw = String(repeating: "字字字字字字字字字。", count: 500)
        let transcript = Transcript(durationSeconds: 3600, rawText: raw)
        try store.save(transcript)
        savedIDs.append(transcript.id)
        let queue = try makeQueue()

        FakeOpenAIServer.queuedReplies = [
            .http(status: 200, body: chat("甲")),
            .http(status: 401, body: ""),
        ]
        let first = await queue.retryPolish(transcript)
        guard case let .polishFailed(partial, failure) = first else {
            return XCTFail("第二塊應該失敗，拿到 \(first)")
        }
        XCTAssertEqual(failure, .invalidAPIKey(statusCode: 401))
        XCTAssertEqual(partial.polishedChunks, ["甲"])
        let landed = try store.loadAll().transcripts.first { $0.id == transcript.id }
        XCTAssertEqual(landed?.polishedChunks, ["甲"], "做好的那塊已經存進去")

        FakeOpenAIServer.reset()
        FakeOpenAIServer.queuedReplies = [
            .http(status: 200, body: chat("乙")),
            .http(status: 200, body: chat("丙")),
        ]
        let second = await queue.retryPolish(partial)
        guard case let .finished(done) = second else {
            return XCTFail("應該整理完，拿到 \(second)")
        }
        XCTAssertEqual(FakeOpenAIServer.requestCount, 2)
        XCTAssertEqual(done.draftText, "甲

乙

丙")
        XCTAssertNil(done.polishedChunks)
    }

    func test續做只補最近一天或做到一半的篇() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-TranscriptionQueue.resumePolishWithinSeconds)
        let old = now.addingTimeInterval(-3 * 24 * 60 * 60)
        let recent = Transcript(createdAt: now, durationSeconds: 60, rawText: "口語稿")
        let oldPartial = Transcript(
            createdAt: old,
            durationSeconds: 60,
            rawText: "口語稿",
            polishedChunks: ["甲"]
        )
        let oldPlain = Transcript(createdAt: old, durationSeconds: 60, rawText: "口語稿")
        let done = Transcript(createdAt: now, durationSeconds: 60, rawText: "口語稿", draftText: "好了")
        let blank = Transcript(createdAt: now, durationSeconds: 60, rawText: "  ")
        XCTAssertTrue(TranscriptionQueue.needsPolishResume(recent, since: cutoff))
        XCTAssertTrue(TranscriptionQueue.needsPolishResume(oldPartial, since: cutoff))
        XCTAssertFalse(TranscriptionQueue.needsPolishResume(oldPlain, since: cutoff))
        XCTAssertFalse(TranscriptionQueue.needsPolishResume(done, since: cutoff))
        XCTAssertFalse(TranscriptionQueue.needsPolishResume(blank, since: cutoff))
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

    /// 一分鐘的靜音：不到一段，整筆只送一次轉錄。
    private func makeRecording() throws -> URL {
        let url = directory.appending(path: "rec-\(UUID().uuidString).wav")
        var writer = try WAVFileWriter(creatingAt: url)
        try writer.append(pcm: Data(repeating: 0, count: 60 * 32000))
        try writer.finish()
        return url
    }
}
