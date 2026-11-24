/// 控制中心按鈕要開錄，走 K1 那條路；已經在錄時首頁會把請求丟掉，不重開也不停。
/// 小工具擴充有一份同名、什麼都不做的：intent 兩邊都要編，開錄的程式只在 App。
enum ControlRecordingRequest {
    @MainActor
    static func send() {
        RecordingLauncher.shared.request = .new
    }
}
