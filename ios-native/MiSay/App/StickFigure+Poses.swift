import SwiftUI

/// 火柴人每個動作在第幾秒長什麼樣。關節角度與節奏照動作庫的 `ANIMS`（idle、think、cheer），
/// 只有慶祝改過：動作庫是一直跳，這裡跳兩下就舉著手站好（完成面板會停很久，一直跳太吵）。
extension StickFigure.Pose {
    static let blinkPeriod: TimeInterval = 3.6
    static let blinkLength: TimeInterval = 0.14
    /// 慶祝跳一下多久、跳幾下。
    static let cheerPeriod: TimeInterval = 0.72
    static let cheerJumps = 2
    private static let breathSpeed: Double = 2.2
    private static let breathLift: Double = 1.2
    private static let swayDegrees: Double = 1.4
    private static let swaySpeed: Double = 1.1
    private static let nodDegrees: Double = 1.5
    private static let nodSpeed: Double = 0.9
    private static let thinkNodSpeed: Double = 1.6
    /// 一下裡面前八成在空中，後兩成是落地壓扁。
    private static let cheerAirShare: Double = 0.8
    private static let cheerHeight: Double = 34
    private static let cheerSquash: Double = 0.07
    private static let cheerKneeBend: Double = 34
    private static let cheerHipSpread: Double = 12
    private static let cheerWiggleSpeed: Double = 15
    private static let cheerWiggleDegrees: Double = 8
    /// 跳完之後手的抖動花多久停下來。
    private static let cheerSettleSeconds: Double = 0.4

    static func moving(for action: StickFigure.Action, at seconds: TimeInterval) -> Self {
        switch action {
        case .idle: idle(at: seconds)
        case .thinking: thinking(at: seconds)
        case .cheering: cheering(at: seconds)
        }
    }

    /// 減少動態、低耗電模式用的那一張：看得出是哪個動作，但不動。
    static func still(for action: StickFigure.Action) -> Self {
        switch action {
        case .idle:
            Self()
        case .thinking:
            thinking(at: 0)
        case .cheering:
            cheering(at: cheerPeriod * Double(cheerJumps) + cheerSettleSeconds, breathes: false)
        }
    }

    /// 待機：身體慢慢晃，每 3.6 秒眨一次眼。
    static func idle(at seconds: TimeInterval) -> Self {
        var pose = Self()
        pose.breathe(at: seconds, strength: 1)
        pose.lean = swayDegrees * sin(seconds * swaySpeed)
        pose.headTilt = nodDegrees * sin(seconds * nodSpeed)
        let sinceBlink = seconds.truncatingRemainder(dividingBy: blinkPeriod)
        if sinceBlink > blinkPeriod - blinkLength {
            pose.eyeHeight = StickFigure.closedEyeHeight
        }
        return pose
    }

    /// 思考：右手托下巴、左手抱胸，頭往左歪、眼睛往左上看，頭上三顆泡泡輪流亮。
    static func thinking(at seconds: TimeInterval) -> Self {
        var pose = Self()
        pose.rightShoulder = 42
        pose.rightElbow = 165
        pose.leftShoulder = -30
        pose.leftElbow = 120
        pose.headTilt = -8 + nodDegrees * sin(seconds * thinkNodSpeed)
        pose.lean = -1.5
        pose.gaze = CGSize(width: -2, height: -3)
        pose.browAngle = 3
        pose.browDrop = -2
        pose.mouth = .flat
        pose.thoughtSeconds = seconds
        return pose
    }

    /// 慶祝：雙手舉高、笑開，頭兩下跳起來（膝蓋往外彎、落地壓扁一下），之後舉著手站好。
    static func cheering(at seconds: TimeInterval, breathes: Bool = true) -> Self {
        let jumpingSeconds = cheerPeriod * Double(cheerJumps)
        let isJumping = seconds < jumpingSeconds
        let phase = seconds.truncatingRemainder(dividingBy: cheerPeriod) / cheerPeriod
        let isInAir = isJumping && phase < cheerAirShare
        let rise = isInAir ? sin(.pi * phase / cheerAirShare) : 0
        let landing = (phase - cheerAirShare) / (1 - cheerAirShare)
        let squash = isJumping && !isInAir ? sin(.pi * landing) : 0
        let settled = min(1, max(0, (seconds - jumpingSeconds) / cheerSettleSeconds))
        let wiggle = cheerWiggleDegrees * sin(seconds * cheerWiggleSpeed) * (1 - settled)

        var pose = Self()
        pose.jump = CGFloat(-cheerHeight * rise)
        pose.squash = CGFloat(cheerSquash * squash)
        pose.leftShoulder = -105
        pose.leftElbow = -62 - wiggle
        pose.rightShoulder = 105
        pose.rightElbow = 62 + wiggle
        pose.leftHip -= cheerHipSpread * rise
        pose.leftKnee = cheerKneeBend * rise
        pose.rightHip += cheerHipSpread * rise
        pose.rightKnee = -cheerKneeBend * rise
        pose.browAngle = -4
        pose.browDrop = -3
        pose.hasHappyEyes = true
        pose.mouth = .open
        if breathes {
            pose.breathe(at: seconds, strength: settled)
        }
        return pose
    }

    private mutating func breathe(at seconds: TimeInterval, strength: Double) {
        let lift = CGFloat(-Self.breathLift * sin(seconds * Self.breathSpeed) * strength)
        shoulderDrop = lift
        headDrop = lift
    }
}
