/// 即時動態的三種狀態，對應 `Recorder` 現有的狀態。
enum RecordingActivityPhase: String, Codable {
    case recording
    /// 被打斷、收音斷了、空間滿了，檔案還開著。
    case paused
    /// 接回去了，還沒有新聲音。
    case waitingForSound
}
