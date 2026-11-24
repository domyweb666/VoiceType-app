/// `OpenRecordingIntent` 應該在 App 裡跑，不會走到這裡；真的開錄的是 App 那份同名的。
/// 真機若只開 App 不開錄，就是走到這裡了，先換 AppIntentsPackage（來源寫在 App 那份）。
enum ControlRecordingRequest {
    @MainActor
    static func send() {}
}
