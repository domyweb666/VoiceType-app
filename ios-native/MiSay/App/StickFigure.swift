import SwiftUI

/// 戴玉米頭套的火柴人（2026-11-15 米選 A 整根玉米）。畫稿與動作庫在 `.uiux/04-手感/玉米火柴人動作庫.html`，
/// 座標與關節角度跟它一樣：0° 垂直向下，正值往畫面右邊轉，手肘與膝蓋是相對上一節的角度。
/// 動 1 待機（空清單），動 2 思考（整理中）、慶祝（好了）。開了減少動態或低耗電模式就停在一張，不重畫。
/// 每個動作的數字在 `StickFigure+Poses.swift`，頭套畫在 `StickFigure+CornHead.swift`。
struct StickFigure: View {
    enum Action {
        /// 輕輕晃、會眨眼。
        case idle
        /// 手托下巴、頭上冒三顆泡泡。
        case thinking
        /// 舉手跳兩下，之後舉著手站好。
        case cheering
    }

    enum Mouth {
        case smile
        case flat
        case open
    }

    /// 一張姿勢：八個關節角度，加上身體的晃動與表情。預設值是站好、雙手收在胸前、微笑。
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
        /// 整個人離地多少（負的是往上跳）。
        var jump: CGFloat = 0
        /// 落地那一下壓扁的比例。
        var squash: CGFloat = 0
        var eyeHeight: CGFloat = StickFigure.openEyeHeight
        /// 笑到眼睛彎起來。
        var hasHappyEyes = false
        /// 眼睛往哪邊看（x 正的往右、y 正的往下）。
        var gaze = CGSize.zero
        /// 眉毛外側往上翹幾度、整條往下移多少。
        var browAngle: Double = 2
        var browDrop: CGFloat = 0
        var mouth = Mouth.smile
        /// 有值就畫頭上的三顆泡泡，值是泡泡閃到第幾秒。
        var thoughtSeconds: Double?
    }

    static let openEyeHeight: CGFloat = 12
    static let closedEyeHeight: CGFloat = 1.5
    /// 一秒畫 30 張就夠：動作不快，省電。
    private static let frameInterval: TimeInterval = 1.0 / 30

    /// 畫稿的格子：寬 200、高 416，腳踩在 406。動作庫是 320 寬，左右各裁掉 60；上面多留 16 給跳起來的玉米鬚。
    private static let boxWidth: CGFloat = 200
    private static let boxHeight: CGFloat = 416
    private static let hipRest = CGPoint(x: 100, y: 286)
    private static let groundY: CGFloat = 406
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
    /// 壓扁時往兩邊撐開的比例（壓 1 撐 0.6）。
    private static let squashWiden: CGFloat = 0.6
    private static let shadowRadiusX: CGFloat = 62
    private static let shadowRadiusY: CGFloat = 8
    private static let shadowBelowGround: CGFloat = 7
    private static let shadowOpacity: Double = 0.16
    /// 跳到這麼高，影子縮到最小、最淡。
    private static let shadowFadeHeight: CGFloat = 40
    private static let shadowShrink: CGFloat = 0.35
    private static let shadowFade: Double = 0.5
    /// 思考的三顆泡泡：相對脖子的位置與半徑，由小到大往左上飄。
    private static let thoughtDots: [(offset: CGPoint, radius: CGFloat)] = [
        (CGPoint(x: -58, y: -104), 4),
        (CGPoint(x: -70, y: -120), 5.5),
        (CGPoint(x: -86, y: -140), 7.5),
    ]
    private static let thoughtSpeed: Double = 3
    private static let thoughtDelay: Double = 0.9
    private static let thoughtMinOpacity: Double = 0.35

    var action = Action.idle
    /// 錄音面板裡用小的（`mascotCompact*`），空清單用大的。
    var isCompact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 動作從出現那一刻算起：慶祝只在一開始跳兩下。
    @State private var startDate = Date()

    var body: some View {
        let isStill = reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
        let width = isCompact ? Token.Shape.mascotCompactWidth : Token.Shape.mascotWidth
        let height = isCompact ? Token.Shape.mascotCompactHeight : Token.Shape.mascotHeight
        TimelineView(.animation(minimumInterval: Self.frameInterval, paused: isStill)) { timeline in
            let seconds = timeline.date.timeIntervalSince(startDate)
            let pose = isStill
                ? Pose.still(for: action)
                : Pose.moving(for: action, at: max(0, seconds))
            Canvas { context, size in
                Self.draw(pose, in: context, size: size)
            }
        }
        .frame(width: width, height: height)
        // 跟 `IconCircle` 一樣是裝飾：旁邊的字已經講了，讀屏不唸。
        .accessibilityHidden(true)
    }

    /// 從 `origin` 往 `degrees` 的方向走 `length`。0° 往下、90° 往右（畫面座標 y 往下長）。
    static func point(from origin: CGPoint, angle degrees: Double, length: CGFloat) -> CGPoint {
        let radians = CGFloat(degrees * .pi / 180)
        return CGPoint(x: origin.x + sin(radians) * length, y: origin.y + cos(radians) * length)
    }
}

/// 畫的部分。拆成 extension 是因為型別本體超過 200 行 SwiftLint 會擋。
extension StickFigure {
    /// 順序照動作庫：影子、腿、身體、頭、手（手要蓋在頭套的葉子上）、泡泡。影子不跟著壓扁。
    private static func draw(_ pose: Pose, in context: GraphicsContext, size: CGSize) {
        var canvas = context
        let scale = min(size.width / boxWidth, size.height / boxHeight)
        canvas.scaleBy(x: scale, y: scale)
        drawShadow(lift: min(1, max(0, -pose.jump / shadowFadeHeight)), in: canvas)

        var figure = canvas
        figure.translateBy(x: hipRest.x, y: groundY)
        figure.scaleBy(x: 1 + pose.squash * squashWiden, y: 1 - pose.squash)
        figure.translateBy(x: -hipRest.x, y: -groundY)
        let ink = GraphicsContext.Shading.color(Token.Colors.textPrimary)
        let hip = CGPoint(x: hipRest.x, y: hipRest.y + pose.jump)
        let neck = point(from: hip, angle: 180 - pose.lean, length: torso)
        let neckDrop = pose.shoulderDrop / 2

        var legs = leg(
            from: hip,
            hipAngle: pose.leftHip,
            kneeAngle: pose.leftKnee,
            toeDirection: -1
        )
        legs.addPath(
            leg(from: hip, hipAngle: pose.rightHip, kneeAngle: pose.rightKnee, toeDirection: 1)
        )
        legs.move(to: hip)
        legs.addLine(to: CGPoint(x: neck.x, y: neck.y + neckDrop))
        figure.stroke(legs, with: ink, style: limbStyle(width: legWidth))

        var head = figure
        head.translateBy(x: neck.x, y: neck.y + pose.headDrop + neckDrop)
        head.rotate(by: .degrees(pose.headTilt + pose.lean))
        drawCornHead(pose, in: head)

        var shoulder = point(from: hip, angle: 180 - pose.lean, length: torso - shoulderBelowNeck)
        shoulder.y += pose.shoulderDrop
        figure.stroke(
            arms(from: shoulder, pose: pose),
            with: ink,
            style: limbStyle(width: armWidth)
        )
        if let seconds = pose.thoughtSeconds {
            drawThought(at: seconds, above: neck, in: figure)
        }
    }

    /// 腳下那片橢圓的影子；跳起來（`lift` 0 到 1）就縮小變淡。
    private static func drawShadow(lift: CGFloat, in context: GraphicsContext) {
        let shrink = 1 - lift * shadowShrink
        let box = CGRect(
            x: hipRest.x - shadowRadiusX * shrink,
            y: groundY + shadowBelowGround - shadowRadiusY * shrink,
            width: shadowRadiusX * shrink * 2,
            height: shadowRadiusY * shrink * 2
        )
        let opacity = shadowOpacity * (1 - Double(lift) * shadowFade)
        context.fill(Path(ellipseIn: box), with: .color(Token.Colors.shadow.opacity(opacity)))
    }

    /// 三顆泡泡輪流亮，看得出還在想。
    private static func drawThought(
        at seconds: Double,
        above neck: CGPoint,
        in context: GraphicsContext
    ) {
        for (index, dot) in thoughtDots.enumerated() {
            let wave = sin(seconds * thoughtSpeed - Double(index) * thoughtDelay)
            let opacity = thoughtMinOpacity + (1 - thoughtMinOpacity) * max(0, wave)
            let box = CGRect(
                x: neck.x + dot.offset.x - dot.radius,
                y: neck.y + dot.offset.y - dot.radius,
                width: dot.radius * 2,
                height: dot.radius * 2
            )
            context.fill(
                Path(ellipseIn: box),
                with: .color(CharacterPalette.cornKernelShade.opacity(opacity))
            )
        }
    }

    private static func leg(
        from hip: CGPoint,
        hipAngle: Double,
        kneeAngle: Double,
        toeDirection: CGFloat
    ) -> Path {
        let knee = point(from: hip, angle: hipAngle, length: thigh)
        let ankle = point(from: knee, angle: hipAngle + kneeAngle, length: shin)
        var path = Path()
        path.move(to: hip)
        path.addLine(to: knee)
        path.addLine(to: ankle)
        path.addLine(to: CGPoint(x: ankle.x + toeDirection * foot, y: ankle.y + 1))
        return path
    }

    private static func arms(from shoulder: CGPoint, pose: Pose) -> Path {
        var path = arm(
            from: CGPoint(x: shoulder.x - shoulderHalfWidth, y: shoulder.y),
            shoulderAngle: pose.leftShoulder,
            elbowAngle: pose.leftElbow
        )
        path.addPath(
            arm(
                from: CGPoint(x: shoulder.x + shoulderHalfWidth, y: shoulder.y),
                shoulderAngle: pose.rightShoulder,
                elbowAngle: pose.rightElbow
            )
        )
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
