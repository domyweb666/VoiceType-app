/// `OpenRecordingIntent` 在 App 裡跑，不會走到這裡；App 那份同名的才會開錄。
enum ControlRecordingRequest {
    @MainActor
    static func send() {}
}
