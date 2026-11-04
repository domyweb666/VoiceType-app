import AVFoundation

/// 方塊 M1：開始錄與每次接回都走這裡開音訊工作階段。
enum RecordingAudioSession {
    static func activate() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            // 來電顯示是橫幅時，只有接起來才打斷。設不成功也照錄，只是來電會斷一下。
            try? session.setPrefersNoInterruptionsFromSystemAlerts(true)
            try session.setActive(true)
        } catch {
            DiagnosticLog.shared.record("音訊工作階段開不起來 \((error as NSError).code)")
            throw Recorder.Failure.audioSessionFailed
        }
    }

    /// 關不掉不影響任何已經寫好的檔，所以不當錯誤。
    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
