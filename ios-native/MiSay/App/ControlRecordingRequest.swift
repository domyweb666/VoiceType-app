/// 控制中心按鈕要開錄，走 K1 那條路（`RecordingLauncher`），已經在錄就丟掉。
/// 小工具擴充有一份同名、什麼都不做的：intent 兩邊都要編，開錄的程式只在 App。
/// `perform` 在哪個程序跑，Apple 文件沒明寫，只說先把 App 叫到前景、兩邊都要編進去：
/// https://developer.apple.com/documentation/appintents/openintent
/// 真機若只開 App 不開錄，就是跑到擴充那份空的去了，先換 AppIntentsPackage：
/// https://developer.apple.com/documentation/appintents/appintentspackage
enum ControlRecordingRequest {
    @MainActor
    static func send() {
        RecordingLauncher.shared.ask(.new)
    }
}
