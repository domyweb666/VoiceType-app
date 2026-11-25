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

        let text = try await makeTranscriber().transcribe(
            fileURL: audio,
            prompt: "提示",
            keywords: []
        )
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
        let text = try await makeTranscriber().transcribe(
            fileURL: audio,
            prompt: "",
            keywords: []
        )
        XCTAssertEqual(text, "第二次成功")
        XCTAssertEqual(FakeOpenAIServer.requestCount, 2)
    }

    func test轉錄金鑰錯不重試只送一次() async throws {
        let audio = try makeAudio(seconds: 1)
        FakeOpenAIServer.reply = .http(status: 401, body: "")
        do {
            _ = try await makeTranscriber().transcribe(
                fileURL: audio,
                prompt: "",
                keywords: []
            )
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
            _ = try await makeTranscriber().transcribe(
                fileURL: audio,
                prompt: "",
                keywords: []
            )
            XCTFail("應該要拋錯")
        } catch let failure as OpenAIClient.Failure {
            XCTAssertEqual(failure, .serverError(statusCode: 503))
        }
        XCTAssertEqual(FakeOpenAIServer.requestCount, Transcriber.maxAttempts)
    }

    func test轉錄提示詞在兩百字內而且含繁體提示與前一段結尾() {
        let previous = String(repeating: "前", count: 300) + "結尾"
        let prompt = TranscriptionPrompt.build(previousText: previous)
        XCTAssertLessThanOrEqual(prompt.count, TranscriptionPrompt.maxCharacters)
        XCTAssertTrue(prompt.hasPrefix(TranscriptionPrompt.traditionalHint))
        XCTAssertTrue(prompt.hasSuffix("結尾"))
        let bare = TranscriptionPrompt.build(previousText: "")
        XCTAssertEqual(bare, TranscriptionPrompt.traditionalHint)
    }

    func test前一段結尾是簡體_送出去的提示轉成繁體() {
        let prompt = TranscriptionPrompt.build(previousText: "这样讲话没问题")
        XCTAssertTrue(prompt.hasSuffix("這樣講話沒問題"), prompt)
    }

    func test詞彙與語言走自己的欄位_不在提示詞裡() async throws {
        let audio = try makeAudio(seconds: 1)
        FakeOpenAIServer.reply = .http(status: 200, body: #"{"text":"好"}"#)
        _ = try await makeTranscriber().transcribe(
            fileURL: audio,
            prompt: TranscriptionPrompt.build(previousText: ""),
            keywords: ["DOMYWEB", "Vibe Coding"]
        )
        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        XCTAssertTrue(body.contains(text: "name=\"keywords[]\"\r\n\r\nDOMYWEB\r\n"))
        XCTAssertTrue(body.contains(text: "name=\"keywords[]\"\r\n\r\nVibe Coding\r\n"))
        XCTAssertTrue(body.contains(text: "name=\"languages[]\"\r\n\r\nzh-tw\r\n"))
        XCTAssertTrue(body.contains(text: "name=\"languages[]\"\r\n\r\nen\r\n"))
        XCTAssertFalse(body.contains(text: "專有名詞"))
    }

    func test會讓整個請求被拒的詞不送() {
        let tooLong = String(repeating: "長", count: TranscriptionKeywords.maxCharacters + 1)
        let words = [" DOMYWEB ", "", "<b>", "a>b", "兩\n行", "兩\r\n行", "有\u{0}控制字", tooLong]
        XCTAssertEqual(TranscriptionKeywords.usable(from: words), ["DOMYWEB"])
    }

    func test詞彙太多留新加的那些() {
        let words = (0 ... TranscriptionKeywords.maxCount).map { "詞\($0)" }
        XCTAssertEqual(TranscriptionKeywords.usable(from: words), Array(words.dropFirst()))
    }

    func test一般與邊錄邊轉都把詞彙帶出去_會被拒的不帶() async throws {
        let job = RecordingTranscriptionJob(
            transcriber: makeTranscriber(),
            vocabulary: ["DOMYWEB", "<b>"]
        )
        FakeOpenAIServer.reply = .http(status: 200, body: #"{"text":"好"}"#)
        _ = try await job.transcribe(recordingAt: makeAudio(seconds: 1))
        try assertSentKeywords()

        FakeOpenAIServer.reset()
        FakeOpenAIServer.reply = .http(status: 200, body: #"{"text":"好"}"#)
        let live = try makeAudio(seconds: 12 * 60)
        await job.transcribeFinishedSegments(
            ofLive: live,
            progressAt: directory.appending(path: "final.wav")
        )
        try assertSentKeywords()
    }

    private func assertSentKeywords() throws {
        let body = try XCTUnwrap(FakeOpenAIServer.lastBody)
        XCTAssertTrue(body.contains(text: "name=\"keywords[]\"\r\n\r\nDOMYWEB\r\n"))
        XCTAssertFalse(body.contains(text: "<b>"))
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
