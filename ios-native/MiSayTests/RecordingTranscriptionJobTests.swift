@testable import MiSay
import XCTest

/// 片 D3：切段與續轉。假伺服器數請求次數，證明失敗後再來只送還沒成功的段。只准在模擬器跑。
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

    func test切段二十五分鐘切成三段每段都是完整WAV() throws {
        let recording = try makeRecording(minutes: 25)
        let segments = try WAVSegmenter.split(recording, into: directory.appending(path: "segments"))
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments.map(\.lastPathComponent), ["rec-25m-01.wav", "rec-25m-02.wav", "rec-25m-03.wav"])
        let sizes = try segments.map { try Data(contentsOf: $0).count }
        XCTAssertEqual(sizes, [44 + 19_200_000, 44 + 19_200_000, 44 + 9_600_000])
        let last = try Data(contentsOf: segments[2])
        XCTAssertEqual(last.littleEndianUInt32(at: 40), 9_600_000)
    }

    func test切段十分鐘以內不切原檔直接用() throws {
        let recording = try makeRecording(minutes: 10)
        let segments = try WAVSegmenter.split(recording, into: directory.appending(path: "segments"))
        XCTAssertEqual(segments, [recording])
    }

    func test續轉第二段失敗後再來只送剩下的段() async throws {
        let recording = try makeRecording(minutes: 25)
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
        let url = directory.appending(path: "rec-\(minutes)m.wav")
        var writer = try WAVFileWriter(creatingAt: url)
        let oneMinute = Data(repeating: 0, count: 60 * 32000)
        for _ in 0 ..< minutes {
            try writer.append(pcm: oneMinute)
        }
        try writer.finish()
        return url
    }
}
