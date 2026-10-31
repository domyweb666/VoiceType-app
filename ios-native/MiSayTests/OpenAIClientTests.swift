@testable import MiSay
import XCTest

/// 片 B2 的行為。測試名字用中文，米在 CI 紀錄裡搜「連線」就看得到驗了什麼。
/// 假金鑰刻意含中文，不會被 pre-commit 當成真金鑰擋下。
/// 只准在模擬器跑：setUp／tearDown 會動 Keychain（規矩檔踩過的坑）。
final class OpenAIClientTests: XCTestCase {
    private let keyStore = APIKeyStore()
    private let fakeKey = "sk-test-假金鑰-連線用"
    private let modelListBody = #"{"object":"list","data":[{"id":"gpt-假模型"}]}"#

    override func setUpWithError() throws {
        try keyStore.save(fakeKey)
        FakeOpenAIServer.reset()
    }

    override func tearDownWithError() throws {
        try keyStore.delete()
        FakeOpenAIServer.reset()
    }

    func test連線金鑰對時驗證通過() async throws {
        FakeOpenAIServer.reply = .http(status: 200, body: modelListBody)
        try await makeClient().verifyAPIKey()
    }

    func test連線金鑰錯時說金鑰不能用而且不可重試() async {
        let body = #"{"error":{"message":"Incorrect API key provided","code":"invalid_api_key"}}"#
        FakeOpenAIServer.reply = .http(status: 401, body: body)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.invalidAPIKey(statusCode: 401))
        XCTAssertEqual(failure?.isRetryable, false)
    }

    func test連線忙線時可重試() async {
        let body = #"{"error":{"message":"Rate limit reached","type":"rate_limit_error"}}"#
        FakeOpenAIServer.reply = .http(status: 429, body: body)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.rateLimited)
        XCTAssertEqual(failure?.isRetryable, true)
    }

    func test連線額度用完時不可重試() async {
        let body = #"{"error":{"message":"You exceeded your quota","type":"insufficient_quota"}}"#
        FakeOpenAIServer.reply = .http(status: 429, body: body)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.quotaExhausted)
        XCTAssertEqual(failure?.isRetryable, false)
    }

    func test連線花費上限到了時不可重試() async {
        let body = #"{"error":{"type":"rate_limit_error","code":"project_spend_limit_exceeded"}}"#
        FakeOpenAIServer.reply = .http(status: 429, body: body)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.quotaExhausted)
        XCTAssertEqual(failure?.isRetryable, false)
    }

    func test連線OpenAI當機時可重試() async {
        FakeOpenAIServer.reply = .http(status: 500, body: "")
        let crashed = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(crashed, OpenAIClient.Failure.serverError(statusCode: 500))
        XCTAssertEqual(crashed?.isRetryable, true)

        FakeOpenAIServer.reply = .http(status: 503, body: "")
        let overloaded = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(overloaded, OpenAIClient.Failure.serverError(statusCode: 503))
        XCTAssertEqual(overloaded?.isRetryable, true)
    }

    func test連線逾時可重試() async {
        FakeOpenAIServer.reply = .failure(.timedOut)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.timedOut)
        XCTAssertEqual(failure?.isRetryable, true)
    }

    func test連線沒網路可重試() async {
        FakeOpenAIServer.reply = .failure(.notConnectedToInternet)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.transport(.notConnectedToInternet))
        XCTAssertEqual(failure?.isRetryable, true)
    }

    func test連線憑證有問題不可重試() async {
        FakeOpenAIServer.reply = .failure(.serverCertificateUntrusted)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.transport(.serverCertificateUntrusted))
        XCTAssertEqual(failure?.isRetryable, false)
    }

    func test連線請求本身有問題時不可重試() async {
        FakeOpenAIServer.reply = .http(status: 400, body: #"{"error":{"message":"bad"}}"#)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.rejected(statusCode: 400))
        XCTAssertEqual(failure?.isRetryable, false)
    }

    func test連線成功卻不是模型清單時當線路不對() async {
        FakeOpenAIServer.reply = .http(status: 200, body: #"{"hello":"world"}"#)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.malformedResponse)
        XCTAssertEqual(failure?.isRetryable, false)
    }

    func test連線沒存金鑰時連請求都不送() async throws {
        try keyStore.delete()
        FakeOpenAIServer.reply = .http(status: 200, body: modelListBody)
        let failure = await caughtFailure { try await makeClient().verifyAPIKey() }
        XCTAssertEqual(failure, OpenAIClient.Failure.missingAPIKey)
        XCTAssertEqual(failure?.isRetryable, false)
        XCTAssertNil(FakeOpenAIServer.lastRequest)
    }

    func test連線錯誤裡找不到金鑰() async {
        // 假伺服器故意把金鑰回聲在錯誤訊息裡，App 拋出的錯誤仍不准帶它（安全標準一）。
        // 走 429：這是唯一會解析錯誤正文的路徑，解完也不准把正文帶出來。
        let message = "Rate limit for " + fakeKey
        let body = #"{"error":{"message":""# + message + #"","type":"rate_limit_error"}}"#
        FakeOpenAIServer.reply = .http(status: 429, body: body)
        do {
            try await makeClient().verifyAPIKey()
            XCTFail("應該要拋錯")
        } catch {
            XCTAssertFalse(String(describing: error).contains(fakeKey))
            XCTAssertFalse(String(reflecting: error).contains(fakeKey))
            XCTAssertFalse(error.localizedDescription.contains(fakeKey))
        }
    }

    func test連線請求只送到OpenAI而且帶金鑰與逾時() async throws {
        FakeOpenAIServer.reply = .http(status: 200, body: modelListBody)
        try await makeClient().verifyAPIKey()
        let request = try XCTUnwrap(FakeOpenAIServer.lastRequest)
        XCTAssertEqual(request.url?.scheme, "https")
        XCTAssertEqual(request.url?.host(), "api.openai.com")
        XCTAssertEqual(request.url?.path(), "/v1/models")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(fakeKey)")
        XCTAssertEqual(request.timeoutInterval, OpenAIClient.verifyTimeoutSeconds)
    }

    func test連線送出的方法與內容類型照呼叫者給的() async throws {
        FakeOpenAIServer.reply = .http(status: 200, body: #"{"ok":true}"#)
        let returned = try await makeClient().send(
            path: "/v1/假路徑",
            method: "POST",
            body: Data(#"{"a":1}"#.utf8),
            contentType: "application/json",
            timeoutSeconds: OpenAIClient.requestTimeoutSeconds
        )
        XCTAssertEqual(returned, Data(#"{"ok":true}"#.utf8))
        let request = try XCTUnwrap(FakeOpenAIServer.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.url?.host(), "api.openai.com")
        XCTAssertEqual(request.timeoutInterval, OpenAIClient.requestTimeoutSeconds)
    }

    func test連線設定沒有放寬ATS() {
        // 安全標準三：ATS 開著、沒有例外。project.yml 沒寫，Info.plist 就不會有這一鍵。
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity"))
    }

    private func makeClient() -> OpenAIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeOpenAIServer.self]
        return OpenAIClient(session: URLSession(configuration: configuration))
    }

    private func caughtFailure(
        _ operation: () async throws -> Void
    ) async -> OpenAIClient.Failure? {
        do {
            try await operation()
            XCTFail("應該要拋錯，卻成功了")
            return nil
        } catch let failure as OpenAIClient.Failure {
            return failure
        } catch {
            XCTFail("拋的不是 OpenAIClient.Failure：\(type(of: error))")
            return nil
        }
    }
}

/// 只存在測試裡的假 OpenAI：攔下 URLSession 的請求，照 `reply` 演一種回答。
/// 不裝套件、不連網路（規矩檔第 2 節）；App 本體看不到這個型別。
final class FakeOpenAIServer: URLProtocol {
    enum Reply {
        case http(status: Int, body: String)
        case failure(URLError.Code)
    }

    nonisolated(unsafe) static var reply: Reply = .http(status: 200, body: "")
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func reset() {
        reply = .http(status: 200, body: "")
        lastRequest = nil
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        switch Self.reply {
        case let .http(status, body):
            guard let url = request.url else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            guard let response else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        }
    }

    override func stopLoading() {}
}
