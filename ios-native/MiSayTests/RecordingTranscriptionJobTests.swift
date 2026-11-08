@testable import MiSay
import XCTest

/// 片 D3、S2-1：切段與續轉。假伺服器數請求次數，證明失敗後再來只送還沒成功的段。只准在模擬器跑。
final class RecordingTranscriptionJobTests: XCTestCase {
    private let keyStore = APIKeyStore()
    private let fakeKey = "sk-test-假金鑰-切段用"
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        try keyStore.save(fakeKey)
        FakeOpenAIServer.reset()
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try keyStore.delete()
        FakeOpenAIServer.reset()
        try FileManager.default.removeItem(at: directory)
    }

    func test切段一小時切成十二段每段五分鐘() throws {
        let recording = try makeRecording(minutes: 60)
        let segments = try WAVSegmenter.plan(recording)
        XCTAssertEqual(segments.count, 12)
        let fiveMinutes = 300 * WAVFileWriter.sampleRate
        XCTAssertTrue(segments.allSatisfy { $0.endFrame - $0.startFrame == fiveMinutes })
        XCTAssertEqual(segments.last?.endFrame, 60 * 60 * WAVFileWriter.sampleRate)
        let oldSegments = RecordingTranscriptionJob.segmentsDirectory(for: recording)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldSegments.path), "不另存切段檔")
    }

    func test切段五分半以內不切() throws {
        let recording = try makeRecording(seconds: 330)
        let segments = try WAVSegmenter.plan(recording)
        XCTAssertEqual(segments, [WAVSegmenter.Segment(startFrame: 0, endFrame: 330 * 16000)])
    }

    func test切段刀下在最安靜的地方() throws {
        let rate = WAVFileWriter.sampleRate
        let quietAt = 280 * rate
        var pcm = Data(repeating: 0x40, count: 600 * rate * 2)
        pcm.replaceSubrange(quietAt * 2 ..< (quietAt + rate / 10) * 2, with: Data(count: rate / 5))
        let url = directory.appending(path: "rec-loud.wav")
        var writer = try WAVFileWriter(creatingAt: url)
        try writer.append(pcm: pcm)
        try writer.finish()

        let segments = try WAVSegmenter.plan(url)
        XCTAssertEqual(segments.first?.endFrame, quietAt)
        XCTAssertEqual(segments.count, 2)
    }

    func test切段不滿三十秒的尾巴併進前一段() {
        let rate = WAVFileWriter.sampleRate
        // 刀都下在搜尋區間的最後一格：350 秒切在約 329.9 秒，尾巴約 20 秒，要併回去。
        let segments = WAVSegmenter.plan(totalFrames: 350 * rate) { range in
            range.upperBound - WAVSegmenter.quietWindowFrames
        }
        XCTAssertEqual(segments, [WAVSegmenter.Segment(startFrame: 0, endFrame: 350 * rate)])
    }

    func test切段讀出來的一段是完整WAV() throws {
        let recording = try makeRecording(minutes: 12)
        let segments = try WAVSegmenter.plan(recording)
        XCTAssertEqual(segments.count, 3)
        let last = try WAVSegmenter.read(segments[2], from: recording)
        XCTAssertEqual(last.count, 44 + 120 * 32000)
        XCTAssertEqual(last.littleEndianUInt32(at: 40), 120 * 32000)
    }

    func test漏字講了一分鐘只回兩個字重送一次還是少就標出來() async throws {
        let url = directory.appending(path: "rec-speech.wav")
        var writer = try WAVFileWriter(creatingAt: url)
        try writer.append(pcm: Data(repeating: 0x40, count: 60 * 32000))
        try writer.finish()
        FakeOpenAIServer.reply = .http(status: 200, body: #"{"text":"嗯。"}"#)

        let job = RecordingTranscriptionJob(transcriber: makeTranscriber())
        _ = try await job.transcribe(recordingAt: url)
        XCTAssertEqual(FakeOpenAIServer.requestCount, 2, "少得不對勁要重送一次")
        XCTAssertEqual(job.possiblyMissingSegments(forRecordingAt: url), [1])
    }

    func test漏字整段靜音回空字不算漏() async throws {
        let recording = try makeRecording(minutes: 1)
        FakeOpenAIServer.reply = .http(status: 200, body: #"{"text":""}"#)
        let job = RecordingTranscriptionJob(transcriber: makeTranscriber())
        _ = try await job.transcribe(recordingAt: recording)
        XCTAssertEqual(FakeOpenAIServer.requestCount, 1)
        XCTAssertNil(job.possiblyMissingSegments(forRecordingAt: recording))
    }

    func test續轉舊版進度檔對不上就從頭轉而且沿用同一篇() async throws {
        let recording = try makeRecording(minutes: 12)
        var legacy = RecordingTranscriptionJob.Progress()
        legacy.segmentTexts = [0: "舊版十分鐘那段的字。"]
        let legacyID = legacy.transcriptID
        let progressURL = RecordingTranscriptionJob.progressURL(for: recording)
        try JSONEncoder().encode(legacy).write(to: progressURL)

        FakeOpenAIServer.reply = .http(status: 200, body: #"{"text":"新。"}"#)
        let job = RecordingTranscriptionJob(transcriber: makeTranscriber())
        let text = try await job.transcribe(recordingAt: recording)
        XCTAssertEqual(text, "新。新。新。")
        XCTAssertEqual(FakeOpenAIServer.requestCount, 3)
        XCTAssertEqual(job.transcriptID(forRecordingAt: recording), legacyID)
    }

    func test續轉第二段失敗後再來只送剩下的段() async throws {
        let recording = try makeRecording(minutes: 12)
        FakeOpenAIServer.queuedReplies = [
            .http(status: 200, body: #"{"text":"第一段。"}"#),
            .http(status: 401, body: ""),
        ]
        let job = RecordingTranscriptionJob(transcriber: makeTranscriber())
        do {
            _ = try await job.transcribe(recordingAt: recording)
            XCTFail("第二段應該失敗")
        } catch let failure as OpenAIClient.Failure {
            XCTAssertEqual(failure, .invalidAPIKey(statusCode: 401))
        }
        XCTAssertEqual(FakeOpenAIServer.requestCount, 2)
        let progressBytes = try Data(contentsOf: RecordingTranscriptionJob.progressURL(for: recording))
        XCTAssertNil(progressBytes.range(of: Data("第一段".utf8)), "進度檔不是明文（S2-4）")

        FakeOpenAIServer.reset()
        FakeOpenAIServer.queuedReplies = [
            .http(status: 200, body: #"{"text":"第二段。"}"#),
            .http(status: 200, body: #"{"text":"第三段。"}"#),
        ]
        let text = try await job.transcribe(recordingAt: recording)
        XCTAssertEqual(text, "第一段。第二段。第三段。")
        XCTAssertEqual(FakeOpenAIServer.requestCount, 2)
        // 第二段的提示詞帶著第一段的結尾
        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        XCTAssertTrue(body.contains(text: "第二段。"))

        job.cleanUp(recordingAt: recording)
        let progress = RecordingTranscriptionJob.progressURL(for: recording)
        XCTAssertFalse(FileManager.default.fileExists(atPath: progress.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recording.path))
    }

    private func makeTranscriber() -> Transcriber {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeOpenAIServer.self]
        let client = OpenAIClient(session: URLSession(configuration: configuration))
        return Transcriber(client: client, retryBaseDelaySeconds: 0.01)
    }

    private func makeRecording(minutes: Int) throws -> URL {
        try makeRecording(seconds: minutes * 60)
    }

    /// 全是靜音：每刀都切在剛好 5:00（一樣安靜時挑離 5 分鐘最近的）。
    private func makeRecording(seconds: Int) throws -> URL {
        let url = directory.appending(path: "rec-\(seconds)s.wav")
        var writer = try WAVFileWriter(creatingAt: url)
        let oneSecond = Data(repeating: 0, count: 32000)
        for _ in 0 ..< seconds {
            try writer.append(pcm: oneSecond)
        }
        try writer.finish()
        return url
    }
}
