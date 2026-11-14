import SwiftUI

/// 戴玉米頭套的火柴人（2026-11-15 米選 A 整根玉米）。畫稿與動作庫在 `.uiux/04-手感/玉米火柴人動作庫.html`，
/// 座標與關節角度跟它一樣：0° 垂直向下，正值往畫面右邊轉，手肘與膝蓋是相對上一節的角度。
/// 動 1 只有待機：輕輕晃、會眨眼。開了減少動態或低耗電模式就停在站好的那一張，不重畫。
/// 頭套畫在 `StickFigure+CornHead.swift`。
struct StickFigure: View {
    /// 一張姿勢：八個關節角度，加上身體的晃動與眼睛開多大。預設值是站好、雙手收在胸前。
    struct Pose: Equatable {
        var leftShoulder: Double = -38
        var leftElbow: Double = 143
        var rightShoulder: Double = 38
        var rightElbow: Double = -143
        var leftHip: Double = -14
        var leftKnee: Double = 0
        var rightHip: Double = 14
        var rightKnee: Double = 0
        /// 整個上半身往右歪幾度。
        var lean: Double = 0
        /// 頭在身體上再多歪幾度。
        var headTilt: Double = 0
        /// 頭、肩膀往下移多少（負的是往上），呼吸用。
        var headDrop: CGFloat = 0
        var shoulderDrop: CGFloat = 0
        var eyeHeight: CGFloat = StickFigure.openEyeHeight

        /// 待機：身體慢慢晃，每 3.6 秒眨一次眼。數字照動作庫的 `ANIMS.idle`。
        static func idle(at seconds: TimeInterval) -> Pose {
            let breath = sin(seconds * StickFigure.breathSpeed)
            let sinceBlink = seconds.truncatingRemainder(dividingBy: StickFigure.blinkPeriod)
            var pose = Pose()
            pose.shoulderDrop = CGFloat(-StickFigure.breathLift * breath)
            pose.headDrop = CGFloat(-StickFigure.breathLift * breath)
            pose.lean = StickFigure.swayDegrees * sin(seconds * StickFigure.swaySpeed)
            pose.headTilt = StickFigure.nodDegrees * sin(seconds * StickFigure.nodSpeed)
            if sinceBlink > StickFigure.blinkPeriod - StickFigure.blinkLength {
                pose.eyeHeight = StickFigure.closedEyeHeight
            }
            return pose
        }
    }

    static let openEyeHeight: CGFloat = 12
    static let closedEyeHeight: CGFloat = 1.5
    static let blinkPeriod: TimeInterval = 3.6
    static let blinkLength: TimeInterval = 0.14
    private static let breathSpeed: Double = 2.2
    private static let breathLift: Double = 1.2
    private static let swayDegrees: Double = 1.4
    private static let swaySpeed: Double = 1.1
    private static let nodDegrees: Double = 1.5
    private static let nodSpeed: Double = 0.9
    /// 一秒畫 30 張就夠：動作很慢，省電。
    private static let frameInterval: TimeInterval = 1.0 / 30

    /// 畫稿的格子：寬 200、高 400，腳踩在 390。動作庫是 320 寬，左右各裁掉 60（待機用不到）。
    private static let boxWidth: CGFloat = 200
    private static let boxHeight: CGFloat = 400
    private static let hip = CGPoint(x: 100, y: 270)
    private static let groundY: CGFloat = 390
    private static let thigh: CGFloat = 62
    private static let shin: CGFloat = 62
    private static let foot: CGFloat = 12
    private static let torso: CGFloat = 78
    private static let shoulderBelowNeck: CGFloat = 12
    private static let shoulderHalfWidth: CGFloat = 6
    private static let upperArm: CGFloat = 44
    private static let forearm: CGFloat = 44
    private static let legWidth: CGFloat = 9
    private static let armWidth: CGFloat = 8.5
    private static let shadowRadiusX: CGFloat = 62
    private static let shadowRadiusY: CGFloat = 8
    private static let shadowBelowGround: CGFloat = 7
    private static let shadowOpacity: Double = 0.16
    /// 腳下那片橢圓的影子。
    private static let shadowBox = CGRect(
        x: hip.x - shadowRadiusX,
        y: groundY + shadowBelowGround - shadowRadiusY,
        width: shadowRadiusX * 2,
        height: shadowRadiusY * 2
    )

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isStill = reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
        TimelineView(.animation(minimumInterval: Self.frameInterval, paused: isStill)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let pose = isStill ? Pose() : Pose.idle(at: seconds)
            Canvas { context, size in
                Self.draw(pose, in: context, size: size)
            }
        }
        .frame(width: Token.Shape.mascotWidth, height: Token.Shape.mascotHeight)
        .accessibilityLabel("玉米")
    }

    /// 從 `origin` 往 `degrees` 的方向走 `length`。0° 往下、90° 往右（畫面座標 y 往下長）。
    static func point(from origin: CGPoint, angle degrees: Double, length: CGFloat) -> CGPoint {
        let radians = CGFloat(degrees * .pi / 180)
        return CGPoint(x: origin.x + sin(radians) * length, y: origin.y + cos(radians) * length)
    }

    /// 順序照動作庫：影子、腿、身體、頭、手（手要蓋在頭套的葉子上）。
    private static func draw(_ pose: Pose, in context: GraphicsContext, size: CGSize) {
        var canvas = context
        let scale = min(size.width / boxWidth, size.height / boxHeight)
        canvas.scaleBy(x: scale, y: scale)
        let ink = GraphicsContext.Shading.color(Token.Colors.textPrimary)
        let neck = point(from: hip, angle: 180 - pose.lean, length: torso)
        let neckDrop = pose.shoulderDrop / 2

        canvas.fill(
            Path(ellipseIn: shadowBox),
            with: .color(Token.Colors.shadow.opacity(shadowOpacity))
        )

        var legs = leg(hipAngle: pose.leftHip, kneeAngle: pose.leftKnee, toeDirection: -1)
        legs.addPath(leg(hipAngle: pose.rightHip, kneeAngle: pose.rightKnee, toeDirection: 1))
        legs.move(to: hip)
        legs.addLine(to: CGPoint(x: neck.x, y: neck.y + neckDrop))
        canvas.stroke(legs, with: ink, style: limbStyle(width: legWidth))

        var head = canvas
        head.translateBy(x: neck.x, y: neck.y + pose.headDrop + neckDrop)
        head.rotate(by: .degrees(pose.headTilt + pose.lean))
        drawCornHead(eyeHeight: pose.eyeHeight, in: head)

        var shoulder = point(from: hip, angle: 180 - pose.lean, length: torso - shoulderBelowNeck)
        shoulder.y += pose.shoulderDrop
        var arms = arm(
            from: CGPoint(x: shoulder.x - shoulderHalfWidth, y: shoulder.y),
            shoulderAngle: pose.leftShoulder,
            elbowAngle: pose.leftElbow
        )
        arms.addPath(arm(
            from: CGPoint(x: shoulder.x + shoulderHalfWidth, y: shoulder.y),
            shoulderAngle: pose.rightShoulder,
            elbowAngle: pose.rightElbow
        ))
        canvas.stroke(arms, with: ink, style: limbStyle(width: armWidth))
    }

    private static func leg(hipAngle: Double, kneeAngle: Double, toeDirection: CGFloat) -> Path {
        let knee = point(from: hip, angle: hipAngle, length: thigh)
        let ankle = point(from: knee, angle: hipAngle + kneeAngle, length: shin)
        var path = Path()
        path.move(to: hip)
        path.addLine(to: knee)
        path.addLine(to: ankle)
        path.addLine(to: CGPoint(x: ankle.x + toeDirection * foot, y: ankle.y + 1))
        return path
    }

    private static func arm(
        from shoulder: CGPoint,
        shoulderAngle: Double,
        elbowAngle: Double
    ) -> Path {
        let elbow = point(from: shoulder, angle: shoulderAngle, length: upperArm)
        var path = Path()
        path.move(to: shoulder)
        path.addLine(to: elbow)
        path.addLine(to: point(from: elbow, angle: shoulderAngle + elbowAngle, length: forearm))
        return path
    }

    private static func limbStyle(width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}
