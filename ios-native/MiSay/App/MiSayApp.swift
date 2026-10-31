import SwiftUI

@main
struct MiSayApp: App {
    /// 整個 App 只有一條待轉錄流水（片 D5）：首頁自動續轉與錄音面板共用，`inFlight` 才擋得住重送。
    @State private var transcriptionQueue = TranscriptionQueue()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environment(transcriptionQueue)
        }
    }
}
