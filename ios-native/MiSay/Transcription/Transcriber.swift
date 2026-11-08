import Foundation

/// 方塊 M3：一個錄音檔（一段）→ 口語稿。只對可重試的錯誤重試，最多 4 次、間隔 2 秒起倍增（舊版）。
/// 切段、續轉在 `RecordingTranscriptionJob`；走的線是 M11。
struct Transcriber {
    enum Failure: Error, Equatable {
        case cannotReadFile
        case malformedResponse
    }

    /// 2026-11-01 查證：舊版的 gpt-4o-mini-transcribe 已標 Deprecated（2027-02-26 關閉），
    /// 官方推薦 gpt-transcribe（每分鐘 0.0045 美元）。米可改。
    static let defaultModel = "gpt-transcribe"
    static let maxAttempts = 4
    static let retryBaseDelaySeconds: Double = 2
    static let endpointPath = "/v1/audio/transcriptions"

    private let client: OpenAIClient
    private let model: String
    private let retryBaseDelaySeconds: Double

    /// 測試用假伺服器時傳自己的 client；重試間隔也只有測試會改短。
    init(
        client: OpenAIClient = OpenAIClient(),
        model: String = Transcriber.defaultModel,
        retryBaseDelaySeconds: Double = Transcriber.retryBaseDelaySeconds
    ) {
        self.client = client
        self.model = model
        self.retryBaseDelaySeconds = retryBaseDelaySeconds
    }

    func transcribe(fileURL: URL, prompt: String) async throws -> String {
        let audio: Data
        do {
            audio = try Data(contentsOf: fileURL)
        } catch {
            throw Failure.cannotReadFile
        }
        return try await transcribe(
            audio: audio,
            filename: fileURL.lastPathComponent,
            prompt: prompt
        )
    }

    /// 長錄音的一段（S2-1）：直接從原檔讀出來的那一段，不落地成檔。
    func transcribe(audio: Data, filename: String, prompt: String) async throws -> String {
        var form = MultipartForm()
        form.addField(name: "model", value: model)
        form.addField(name: "response_format", value: "json")
        if !prompt.isEmpty {
            form.addField(name: "prompt", value: prompt)
        }
        form.addFile(
            name: "file",
            filename: filename,
            contentType: "audio/wav",
            data: audio
        )

        let data = try await OpenAIClient.retrying(
            maxAttempts: Self.maxAttempts,
            baseDelaySeconds: retryBaseDelaySeconds
        ) {
            try await client.send(
                path: Self.endpointPath,
                method: "POST",
                body: form.body,
                contentType: form.contentType,
                timeoutSeconds: OpenAIClient.requestTimeoutSeconds
            )
        }
        let response = try? JSONDecoder().decode(TranscriptionResponse.self, from: data)
        guard let response else {
            throw Failure.malformedResponse
        }
        return response.text
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
    }
}
