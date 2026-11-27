import AppIntents

/// 控制中心「開始錄音」按下去做的事：打開米說並開錄。
/// Apple 規定 App 與擴充都要編進這個型別才打得開 App；系統把 App 叫到前景之後才跑 `perform`：
/// https://developer.apple.com/documentation/appintents/openintent
/// 不用 `StartRecordingIntent`：它靠 `openAppWhenRun`，Apple 文件說那個在擴充裡會出錯。
struct OpenRecordingIntent: OpenIntent {
    static let title: LocalizedStringResource = "開始錄音"
    static let description = IntentDescription("打開芋音，直接開始錄。")
    /// 捷徑裡已經有 K1 的「開始錄音」，不要出現兩個同名的。
    static let isDiscoverable = false

    @Parameter(title: "打開", default: .recording)
    var target: OpenRecordingTarget

    @MainActor
    func perform() async throws -> some IntentResult {
        ControlRecordingRequest.send()
        return .result()
    }
}
