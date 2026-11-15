import SwiftUI

/// 火柴人每個動作在第幾秒長什麼樣。關節角度與節奏照動作庫的 `ANIMS`（idle、think、cheer、wave、point 的 up、bow）。
/// 改過兩個：慶祝在動作庫是一直跳，這裡跳兩下就舉著手站好（完成面板會停很久，一直跳太吵）；
/// 鞠躬在動作庫會把上半身壓短，這裡只低頭閉眼（正面看不出彎腰，少兩個只有它用的欄位）。
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
    private static let waveSpeed: Double = 9
    private static let waveNodSpeed: Double = 4.5
    private static let pointBounceSpeed: Double = 5
    /// 鞠躬一輪 2.6 秒：0.45 秒低下去，停到 1.5 秒，2 秒抬回來。
    private static let bowPeriod: Double = 2.6
    private static let bowDownSeconds: Double = 0.45
    private static let bowRiseStart: Double = 1.5
    private static let bowRiseEnd: Double = 2
    private static let bowLowestSeconds: Double = 1

    static func moving(for action: StickFigure.Action, at seconds: TimeInterval) -> Self {
        switch action {
        case .idle: idle(at: seconds)
        case .thinking: thinking(at: seconds)
        case .cheering: cheering(at: seconds)
        case .waving: waving(at: seconds)
        case .pointingUp: pointingUp(at: seconds)
        case .bowing: bowing(at: seconds)
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
        case .waving:
            waving(at: 0)
        case .pointingUp:
            pointingUp(at: 0)
        case .bowing:
            bowing(at: bowLowestSeconds)
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

    /// 揮手：右手舉起來，前臂左右擺，頭跟著點。
    static func waving(at seconds: TimeInterval) -> Self {
        var pose = Self()
        pose.rightShoulder = 110
        pose.rightElbow = 40 + 22 * sin(seconds * waveSpeed)
        pose.leftShoulder = -16
        pose.leftElbow = -6
        pose.headTilt = 5 + 2 * sin(seconds * waveNodSpeed)
        pose.lean = 2
        pose.browAngle = 5
        pose.browDrop = -1
        pose.headDrop = CGFloat(-sin(seconds * waveNodSpeed))
        return pose
    }

    /// 往上指：右手舉過頭，眼睛往上看，整個人輕輕一頓一頓。
    static func pointingUp(at seconds: TimeInterval) -> Self {
        let bounce = CGFloat(-1.5 * sin(seconds * pointBounceSpeed))
        var pose = Self()
        pose.rightShoulder = 105
        pose.rightElbow = 62
        pose.leftShoulder = -40
        pose.leftElbow = 100
        pose.headDrop = bounce
        pose.shoulderDrop = bounce
        pose.headTilt = -4
        pose.gaze = CGSize(width: 1, height: -3)
        pose.browAngle = 4
        return pose
    }

    /// 鞠躬：雙手放下，頭低下去、眼睛閉起來，停一下再抬回來。
    static func bowing(at seconds: TimeInterval) -> Self {
        let cycle = seconds.truncatingRemainder(dividingBy: bowPeriod)
        let depth = smooth(0, bowDownSeconds, cycle) * (1 - smooth(bowRiseStart, bowRiseEnd, cycle))
        let eyeRange = StickFigure.openEyeHeight - StickFigure.closedEyeHeight
        let eyeClose = eyeRange * smooth(0.4, 0.8, depth)
        var pose = Self()
        pose.leftShoulder = -12
        pose.leftElbow = -4
        pose.rightShoulder = 12
        pose.rightElbow = 4
        pose.headDrop = CGFloat(8 * depth)
        pose.shoulderDrop = CGFloat(3 * depth)
        pose.gaze = CGSize(width: 0, height: 6 * depth)
        pose.eyeHeight = StickFigure.openEyeHeight - eyeClose
        pose.browDrop = CGFloat(2 * depth)
        return pose
    }

    /// 0 到 1 的平滑過渡（動作庫的 `ss`）：`value` 在 `start` 之前是 0、`end` 之後是 1。
    private static func smooth(_ start: Double, _ end: Double, _ value: Double) -> Double {
        let ratio = min(1, max(0, (value - start) / (end - start)))
        return ratio * ratio * (3 - 2 * ratio)
    }

    private mutating func breathe(at seconds: TimeInterval, strength: Double) {
        let lift = CGFloat(-Self.breathLift * sin(seconds * Self.breathSpeed) * strength)
        shoulderDrop = lift
        headDrop = lift
    }
}
