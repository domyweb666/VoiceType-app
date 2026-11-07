import Foundation

/// 錄音面板給人看、給人唸的字串。純函式，有測試；2026-11-07 從面板檔搬出來，讓面板檔留在 300 行內。
extension RecordingSheetView {
    /// 給人唸的：「2 分 17 秒」；不到一分鐘「17 秒」；超過一小時「1 小時 2 分 17 秒」。
    static func formatSpoken(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours) 小時")
        }
        if minutes > 0 {
            parts.append("\(minutes) 分")
        }
        parts.append("\(secs) 秒")
        return parts.joined(separator: " ")
    }

    /// 「02:17」；超過一小時「1:02:17」。
    static func formatElapsed(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// 沒在收音時那一句。第一句回答有沒有損失之前先講發生什麼，因為使用者是回頭才看到這裡。
    static func pausedMessage(for reason: Recorder.PauseReason?, elapsed: Double) -> String {
        let saved = "已錄到的 \(formatSpoken(elapsed)) 都在。"
        switch reason {
        case .outOfSpace:
            return "手機空間快滿了，先停了。\(saved)清出空間可以按繼續錄。"
        case .lostInput:
            return "收音斷了，正在接回去。\(saved)"
        case .interrupted, nil:
            return "被打斷了，結束後會自己接回去。\(saved)"
        }
    }

    /// 完成面板那一行；沒斷過是 nil。
    static func gapText(for gaps: CaptureWatch.Gaps) -> String? {
        guard gaps.times > 0 else {
            return nil
        }
        let length = gaps.seconds < 1 ? "不到 1 秒" : formatSpoken(gaps.seconds)
        return "中間斷過 \(gaps.times) 次，共 \(length)。"
    }
}
