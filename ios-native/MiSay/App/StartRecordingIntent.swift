import AppIntents

/// K1 一鍵開錄：捷徑、Siri、動作按鈕都叫這個。打開米說、直接開始錄。
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "開始錄音"
    static let description = IntentDescription("打開米說，直接開始錄。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        RecordingLauncher.shared.request = .new
        return .result()
    }
}

/// 不用自己建捷徑：裝好米說，捷徑 App、Siri、動作按鈕的選單裡就有「開始錄音」。
struct MiSayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "用\(.applicationName)開始錄音",
                "\(.applicationName)錄音",
            ],
            shortTitle: "開始錄音",
            systemImageName: "mic"
        )
    }
}
