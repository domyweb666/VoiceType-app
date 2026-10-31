@testable import MiSay
import XCTest

/// 片 D2：單段轉錄。假伺服器攔請求，真的 OpenAI 要等米親手錄。只准在模擬器跑（會動 Keychain）。
final class TranscriberTests: XCTestCase {
    private let keyStore = APIKeyStore()
    private let fakeKey = "sk-test-假金鑰-轉錄用"
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

    func test轉錄送出的是multipart而且帶模型檔案與提示詞() async throws {
        let audio = try makeAudio(seconds: 1)
        FakeOpenAIServer.reply = .http(status: 200, body: #"{"text":"剛剛想到一件事"}"#)

        let text = try await makeTranscriber().transcribe(fileURL: audio, prompt: "提示")
        XCTAssertEqual(text, "剛剛想到一件事")

        let request = try XCTUnwrap(FakeOpenAIServer.lastRequest)
        XCTAssertEqual(request.url?.path(), Transcriber.endpointPath)
        XCTAssertEqual(request.httpMethod, "POST")
        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        XCTAssertTrue(body.contains(text: "name=\"model\"\r\n\r\ngpt-transcribe"))
        XCTAssertTrue(body.contains(text: "name=\"prompt\"\r\n\r\n提示"))
        XCTAssertTrue(body.contains(text: "name=\"file\"; filename=\"\(audio.lastPathComponent)\""))
        XCTAssertTrue(body.contains(text: "Content-Type: audio/wav"))
        XCTAssertTrue(body.contains(text: "RIFF"))
    }

    func test轉錄暫時錯誤會重試成功() async throws {
        let audio = try makeAudio(seconds: 1)
        FakeOpenAIServer.queuedReplies = [
            .http(status: 500, body: ""),
            .http(status: 200, body: #"{"text":"第二次成功"}"#),
        ]
        let text = try await makeTranscriber().transcribe(fileURL: audio, prompt: "")
        XCTAssertEqual(text, "第二次成功")
        XCTAssertEqual(FakeOpenAIServer.requestCount, 2)
    }

    func test轉錄金鑰錯不重試只送一次() async throws {
        let audio = try makeAudio(seconds: 1)
        FakeOpenAIServer.reply = .http(status: 401, body: "")
        do {
            _ = try await makeTranscriber().transcribe(fileURL: audio, prompt: "")
            XCTFail("應該要拋錯")
        } catch let failure as OpenAIClient.Failure {
            XCTAssertEqual(failure, .invalidAPIKey(statusCode: 401))
        }
        XCTAssertEqual(FakeOpenAIServer.requestCount, 1)
    }

    func test轉錄最多四次之後放棄() async throws {
        let audio = try makeAudio(seconds: 1)
        FakeOpenAIServer.reply = .http(status: 503, body: "")
        do {
            _ = try await makeTranscriber().transcribe(fileURL: audio, prompt: "")
            XCTFail("應該要拋錯")
        } catch let failure as OpenAIClient.Failure {
            XCTAssertEqual(failure, .serverError(statusCode: 503))
        }
        XCTAssertEqual(FakeOpenAIServer.requestCount, Transcriber.maxAttempts)
    }

    func test轉錄提示詞在兩百字內而且含繁體提示詞彙與前一段結尾() {
        let previous = String(repeating: "前", count: 300) + "結尾"
        let prompt = TranscriptionPrompt.build(vocabulary: ["DOMYWEB", " Vibe Coding "], previousText: previous)
        XCTAssertLessThanOrEqual(prompt.count, TranscriptionPrompt.maxCharacters)
        XCTAssertTrue(prompt.hasPrefix(TranscriptionPrompt.traditionalHint))
        XCTAssertTrue(prompt.contains("專有名詞：DOMYWEB、Vibe Coding"))
        XCTAssertTrue(prompt.hasSuffix("結尾"))
        XCTAssertEqual(TranscriptionPrompt.build(vocabulary: [], previousText: ""), TranscriptionPrompt.traditionalHint)
    }

    private func makeTranscriber() -> Transcriber {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeOpenAIServer.self]
        let client = OpenAIClient(session: URLSession(configuration: configuration))
        return Transcriber(client: client, retryBaseDelaySeconds: 0.01)
    }

    private func makeAudio(seconds: Int) throws -> URL {
        let url = directory.appending(path: "audio-\(seconds)s.wav")
        var writer = try WAVFileWriter(creatingAt: url)
        try writer.append(pcm: Data(repeating: 0, count: seconds * 32000))
        try writer.finish()
        return url
    }
}

extension Data {
    func contains(text: String) -> Bool {
        range(of: Data(text.utf8)) != nil
    }
}
