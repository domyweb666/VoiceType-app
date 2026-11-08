import Foundation

/// 方塊 M11：只通到 OpenAI 的那條線。藍圖裡 M3 轉錄、M4 潤飾送請求、M6 驗證金鑰都走這裡。
/// 只做三件事：從 Keychain 拿金鑰帶在請求上、等太久就放棄、把回應分成「可以再試／再試也沒用」。
/// 不重試（次數與間隔是 D2、D4 的事）、不記請求內容（診斷紀錄只有錯誤種類）、沒有畫面。
/// 錯誤只帶狀態碼與分類；OpenAI 回的錯誤正文一律不往外帶，因為正文可能把金鑰回聲出來（安全標準一）。
struct OpenAIClient {
    enum Failure: Error, Equatable {
        /// Keychain 裡沒有金鑰；請求根本沒送出去。
        case missingAPIKey
        /// 路徑拼不成合法網址：是程式自己寫錯，不是網路的事。
        case invalidPath
        /// 401、403：金鑰錯、被撤銷、或地區不支援。換金鑰才會好。
        case invalidAPIKey(statusCode: Int)
        /// 429 但 OpenAI 說是額度用完或花費上限：等再久都一樣，要去 OpenAI 後台處理。
        case quotaExhausted
        /// 429 速率太快：等一下再試會好。
        case rateLimited
        /// 5xx：OpenAI 那邊的問題，稍後再試。
        case serverError(statusCode: Int)
        /// 其他 4xx（400、404、413、422…）：請求本身有問題，重送一樣的東西不會好。
        case rejected(statusCode: Int)
        /// 回來的不是 HTTP、或成功卻不是說好的 JSON 形狀。
        case malformedResponse
        /// 等超過逾時秒數沒回音。
        case timedOut
        /// 連線層的錯（沒網路、找不到主機、憑證不對、被取消…）；哪些能再試看 `isRetryable`。
        case transport(URLError.Code)

        /// 上層（D2 轉錄、D4 潤飾）只對 true 的錯誤重試，而且次數由它們管。
        var isRetryable: Bool {
            switch self {
            case .rateLimited, .serverError, .timedOut:
                true
            case let .transport(code):
                Self.retryableTransportCodes.contains(code)
            case .missingAPIKey, .invalidPath, .invalidAPIKey, .quotaExhausted:
                false
            case .rejected, .malformedResponse:
                false
            }
        }

        /// 沿用舊版 Flutter 的分法：連不上、連線中斷算暫時的；
        /// 憑證錯、被取消、其他不明的一律倒向「不重試」（規矩檔第 4 條：爆了倒向拒絕）。
        private static let retryableTransportCodes: [URLError.Code] = [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed,
            .dataNotAllowed,
            .internationalRoamingOff,
        ]

        /// 照 OpenAI 官方錯誤碼文件（2026-11-01 查證）分堆。正文只拿來看 429 是哪一種，不往外帶。
        init(statusCode: Int, body: Data) {
            switch statusCode {
            case 401, 403:
                self = .invalidAPIKey(statusCode: statusCode)
            case 429:
                self = Self.isQuotaError(body) ? .quotaExhausted : .rateLimited
            case 500...:
                self = .serverError(statusCode: statusCode)
            default:
                self = .rejected(statusCode: statusCode)
            }
        }

        init(urlError: URLError) {
            self = urlError.code == .timedOut ? .timedOut : .transport(urlError.code)
        }

        /// 官方文件點名「重試也沒用」的 429：`error.code` 是這幾個，或 `error.type` 是 insufficient_quota。
        private static let quotaCodes = [
            "credit_balance_exhausted",
            "organization_spend_limit_exceeded",
            "project_spend_limit_exceeded",
            "organization_usage_limit_exceeded",
        ]

        private static func isQuotaError(_ body: Data) -> Bool {
            // 正文看不懂就當速率限制：429 不收費，而且上層的重試有上限，最多多等幾秒。
            guard let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: body) else {
                return false
            }
            if envelope.error.type == "insufficient_quota" {
                return true
            }
            return quotaCodes.contains(envelope.error.code ?? "")
        }
    }

    /// 一般請求等這麼久沒動靜就放棄。S2-2 從 60 拉到 180：照公開速度，一小時的稿整篇潤飾要 72～86 秒，
    /// 60 秒三次都會超時；分塊後一塊約 10 秒，180 留給網路慢的時候。
    static let requestTimeoutSeconds: TimeInterval = 180
    /// 驗證金鑰要「馬上知道」，等太久跟不能用沒兩樣（沿用舊版 15 秒）。
    static let verifyTimeoutSeconds: TimeInterval = 15

    /// 唯一准連的主機（安全標準三）。要改等於改藍圖，先回去問米。
    private static let baseURL = "https://api.openai.com"

    private let session: URLSession
    private let keyStore = APIKeyStore()

    /// 測試用假伺服器時傳自己的 session；App 裡用預設。
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 問 OpenAI「這把金鑰能用嗎」：打免費的 `GET /v1/models`。
    /// 正常回來就是能用；不能用的原因看拋出的 `Failure`（Keychain 讀不到時拋 `APIKeyStore.Failure`）。
    func verifyAPIKey() async throws {
        let data = try await send(
            path: "/v1/models",
            method: "GET",
            body: nil,
            contentType: nil,
            timeoutSeconds: Self.verifyTimeoutSeconds
        )
        // 成功也要驗形狀（規矩檔第 3 節）：回了 200 卻不是模型清單，就當線路不對。
        let list: ModelList
        do {
            list = try JSONDecoder().decode(ModelList.self, from: data)
        } catch {
            throw Failure.malformedResponse
        }
        guard list.object == "list" else {
            throw Failure.malformedResponse
        }
    }

    /// 帶金鑰送一個請求到 OpenAI，回成功時的正文；失敗一律拋 `Failure`。
    /// M3 轉錄、M4 潤飾之後也走這裡：它們只決定路徑與正文，不碰金鑰與主機。
    func send(
        path: String,
        method: String,
        body: Data?,
        contentType: String?,
        timeoutSeconds: TimeInterval
    ) async throws -> Data {
        guard let apiKey = try keyStore.read() else {
            throw Failure.missingAPIKey
        }
        guard let url = URL(string: Self.baseURL + path) else {
            throw Failure.invalidPath
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let error as URLError {
            throw Failure(urlError: error)
        } catch {
            // URLSession 照理只拋 URLError；真的拋了別的，當不明連線錯，不重試。
            throw Failure.transport(.unknown)
        }

        let (data, response) = result
        guard let http = response as? HTTPURLResponse else {
            throw Failure.malformedResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Failure(statusCode: http.statusCode, body: data)
        }
        return data
    }

    /// 片 D2／D4 共用的重試迴圈：只對 `Failure.isRetryable` 的錯重試，次數與起始間隔由呼叫端給
    /// （轉錄 4 次、潤飾 3 次，PRD），間隔每次加倍（舊版）。不可重試的錯第一次就拋出去。
    static func retrying<Result>(
        maxAttempts: Int,
        baseDelaySeconds: Double,
        _ operation: () async throws -> Result
    ) async throws -> Result {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch let failure as Failure where failure.isRetryable && attempt < maxAttempts {
                DiagnosticLog.shared.record("第 \(attempt) 次沒成功，再試：\(failure)")
                let delay = baseDelaySeconds * pow(2, Double(attempt - 1))
                try await Task.sleep(for: .seconds(delay))
                attempt += 1
            }
        }
    }

    /// `GET /v1/models` 成功時的形狀（官方文件：object 固定是 "list"）。只用來驗證，不存、不畫。
    private struct ModelList: Decodable {
        let object: String
    }

    /// OpenAI 錯誤正文裡我們唯一會看的兩個欄位；message 刻意不解，裡面可能有金鑰。
    private struct ErrorEnvelope: Decodable {
        let error: ErrorDetail
    }

    private struct ErrorDetail: Decodable {
        let code: String?
        let type: String?
    }
}
