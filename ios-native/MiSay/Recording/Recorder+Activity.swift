extension Recorder {
    /// 把現在的狀態丟給鎖定畫面與靈動島，丟完就走，不等結果。
    func showOnLockScreen() {
        RecordingActivityPresenter.shared.recordingIsRunning(
            RecordingActivityPlan.Status(
                isPaused: isPaused,
                isWaitingForSound: isWaitingForSound,
                elapsedSeconds: elapsedSeconds
            )
        )
    }
}
