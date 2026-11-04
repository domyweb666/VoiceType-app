import SwiftUI

@main
struct MiSayApp: App {
    /// 整個 App 只有一條待轉錄流水（片 D5）：首頁自動續轉與錄音面板共用，`inFlight` 才擋得住重送。
    @State private var transcriptionQueue = TranscriptionQueue()
    /// 錄音狀態也放這層（組塊 S）：不跟著面板消失，撿回救回檔時問得到它在不在錄。
    @State private var recorder = Recorder()

    var body: some Scene {
        WindowGroup {
            RootPagerView()
                .environment(transcriptionQueue)
                .environment(recorder)
        }
    }
}
