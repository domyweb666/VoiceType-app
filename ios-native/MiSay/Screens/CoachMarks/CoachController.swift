import Foundation
import Observation

/// 引導的狀態：現在第幾步、有沒有在進行、每個目標元件在螢幕上的位置。
/// 「看過了」只在走完或跳過時寫；中途 App 被關掉就當沒看過，下次從第一步重來。
@Observable
final class CoachController {
    /// 步驟大改時把 v1 換成 v2，看過的人會再看一次。
    static let completedKey = "coachTour.detail.v1.completed"

    let steps: [CoachStep]
    private(set) var stepIndex = 0
    private(set) var isActive = false
    /// 設定頁按了「重看教學」、還沒開始：下一個出現的文字稿詳情頁不管看沒看過都開始。
    private(set) var wantsReplay = false
    /// 每按一次加一。根畫面看到它變了就切到文字稿、打開最新一篇。
    private(set) var replayRequests = 0
    /// 目標元件回報的螢幕座標（`CoachTarget`）。沒回報的那一步不挖洞，說明卡照樣出現。
    var frames: [String: CGRect] = [:]
    private let defaults: UserDefaults

    init(steps: [CoachStep] = CoachTour.steps, defaults: UserDefaults = .standard) {
        self.steps = steps
        self.defaults = defaults
    }

    var currentStep: CoachStep? {
        guard isActive, steps.indices.contains(stepIndex) else {
            return nil
        }
        return steps[stepIndex]
    }

    var hasCompleted: Bool {
        defaults.bool(forKey: Self.completedKey)
    }

    /// 第一次打開整理好的文字稿時叫這個；看過就不再出現。
    func startIfFirstTime() {
        guard !hasCompleted else {
            return
        }
        start()
    }

    func start() {
        guard !isActive, !steps.isEmpty else {
            return
        }
        wantsReplay = false
        stepIndex = 0
        isActive = true
    }

    /// 設定頁「重看教學」。引導正在跑就不理。
    func requestReplay() {
        guard !isActive else {
            return
        }
        wantsReplay = true
        replayRequests += 1
    }

    /// 找不到可以帶引導的文字稿：收回剛才那次要求，免得之後打開別篇突然開始。
    func cancelReplay() {
        wantsReplay = false
    }

    /// 下一步；已經是最後一步就結束。
    func next() {
        guard isActive else {
            return
        }
        if stepIndex + 1 < steps.count {
            stepIndex += 1
        } else {
            finishAndRemember()
        }
    }

    func skip() {
        guard isActive else {
            return
        }
        finishAndRemember()
    }

    private func finishAndRemember() {
        isActive = false
        frames = [:]
        defaults.set(true, forKey: Self.completedKey)
    }
}
