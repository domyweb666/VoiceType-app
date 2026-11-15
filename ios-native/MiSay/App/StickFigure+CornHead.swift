import SwiftUI

/// 火柴人的頭套 A「整根玉米」：臉直接長在玉米上，頭頂三根玉米鬚，下面兩片葉子當領子。
/// 座標是動作庫 `HEADS.cornA` 的原樣：原點在脖子，往上是負的，臉的中心在 (0, -46)。
/// 顏色只用角色色（使用規則第 3 條）；五官用玉米黃上面的深色字，淺色深色模式都看得到。
extension StickFigure {
    private static let faceCenter = CGPoint(x: 0, y: -46)
    /// 臉周圍這個半徑裡不畫玉米粒，五官才看得清楚。
    private static let faceClearRadius: CGFloat = 35
    private static let kernelSize = CGSize(width: 10.4, height: 8.8)
    private static let kernelRowGap: CGFloat = 11
    private static let kernelColumnGap: CGFloat = 13
    private static let silkWidth: CGFloat = 3
    private static let faceLineWidth: CGFloat = 3.2
    private static let eyeWidth: CGFloat = 4.6
    private static let eyeCenterY: CGFloat = -48
    private static let eyeOffsetX: CGFloat = 11
    /// 笑彎的眼睛：一道往上拱的弧，半寬 5、兩端比中心低 3、拱到中心上面 6。
    private static let happyEyeHalfWidth: CGFloat = 5
    private static let happyEyeEnds: CGFloat = 3
    private static let happyEyeArch: CGFloat = 6
    private static let browOffsetX: CGFloat = 12
    private static let browCenterY: CGFloat = -61
    private static let browHalfLength: CGFloat = 8
    private static let mouthCenterY: CGFloat = -30
    /// 眉毛和嘴跟著眼神動一半，看起來整張臉在轉。
    private static let gazeFollow: CGFloat = 0.5

    static func drawCornHead(_ pose: Pose, in context: GraphicsContext) {
        let shade = GraphicsContext.Shading.color(CharacterPalette.cornKernelShade)
        let ink = GraphicsContext.Shading.color(Token.Colors.actionInk)
        let roundLine = StrokeStyle(lineWidth: silkWidth, lineCap: .round)
        context.stroke(silk, with: shade, style: roundLine)
        context.fill(cob, with: .color(CharacterPalette.cornKernel))
        var insideCob = context
        insideCob.clip(to: cob)
        insideCob.fill(kernels, with: shade)
        context.fill(husks, with: .color(CharacterPalette.cornHusk))
        context.fill(faceFills(pose), with: ink)
        context.stroke(
            faceLines(pose),
            with: ink,
            style: StrokeStyle(lineWidth: faceLineWidth, lineCap: .round)
        )
    }

    /// 填滿的五官：睜著的眼睛（兩顆直的膠囊）、張開的嘴。
    private static func faceFills(_ pose: Pose) -> Path {
        var path = Path()
        if !pose.hasHappyEyes {
            for side: CGFloat in [-1, 1] {
                let eye = CGRect(
                    x: side * eyeOffsetX + pose.gaze.width - eyeWidth / 2,
                    y: eyeCenterY + pose.gaze.height - pose.eyeHeight / 2,
                    width: eyeWidth,
                    height: pose.eyeHeight
                )
                let corner = CGSize(width: eyeWidth / 2, height: min(eyeWidth, pose.eyeHeight) / 2)
                path.addRoundedRect(in: eye, cornerSize: corner)
            }
        }
        if pose.mouth == .open {
            let center = mouthCenter(pose)
            path.move(to: CGPoint(x: center.x - 7, y: center.y - 2))
            path.addQuadCurve(
                to: CGPoint(x: center.x + 7, y: center.y - 2),
                control: CGPoint(x: center.x, y: center.y + 10)
            )
            path.closeSubpath()
        }
        return path
    }

    /// 用線畫的五官：眉毛、笑彎的眼睛、微笑或抿嘴。
    private static func faceLines(_ pose: Pose) -> Path {
        var path = Path()
        let browRadians = CGFloat(pose.browAngle * .pi / 180)
        let browRun = browHalfLength * cos(browRadians)
        let browRise = browHalfLength * sin(browRadians)
        for side: CGFloat in [-1, 1] {
            let browX = side * browOffsetX + pose.gaze.width * gazeFollow
            let browY = browCenterY + pose.browDrop + pose.gaze.height * gazeFollow
            path.move(to: CGPoint(x: browX - side * browRun, y: browY + browRise))
            path.addLine(to: CGPoint(x: browX + side * browRun, y: browY - browRise))
            if pose.hasHappyEyes {
                let eyeX = side * eyeOffsetX + pose.gaze.width
                let eyeY = eyeCenterY + pose.gaze.height
                path.move(to: CGPoint(x: eyeX - happyEyeHalfWidth, y: eyeY + happyEyeEnds))
                path.addQuadCurve(
                    to: CGPoint(x: eyeX + happyEyeHalfWidth, y: eyeY + happyEyeEnds),
                    control: CGPoint(x: eyeX, y: eyeY - happyEyeArch)
                )
            }
        }
        let center = mouthCenter(pose)
        switch pose.mouth {
        case .smile:
            path.move(to: CGPoint(x: center.x - 6, y: center.y - 1))
            path.addQuadCurve(
                to: CGPoint(x: center.x + 6, y: center.y - 1),
                control: CGPoint(x: center.x, y: center.y + 5)
            )
        case .flat:
            path.move(to: CGPoint(x: center.x - 5, y: center.y))
            path.addLine(to: CGPoint(x: center.x + 5, y: center.y))
        case .open:
            break
        }
        return path
    }

    private static func mouthCenter(_ pose: Pose) -> CGPoint {
        CGPoint(
            x: pose.gaze.width * gazeFollow,
            y: mouthCenterY + pose.gaze.height * gazeFollow
        )
    }

    private static let silk: Path = {
        var path = Path()
        path.move(to: CGPoint(x: -3, y: -136))
        path.addCurve(
            to: CGPoint(x: -14, y: -166),
            control1: CGPoint(x: -10, y: -150),
            control2: CGPoint(x: -6, y: -160)
        )
        path.move(to: CGPoint(x: 0, y: -137))
        path.addCurve(
            to: CGPoint(x: 2, y: -168),
            control1: CGPoint(x: 0, y: -152),
            control2: CGPoint(x: 6, y: -158)
        )
        path.move(to: CGPoint(x: 3, y: -136))
        path.addCurve(
            to: CGPoint(x: 18, y: -162),
            control1: CGPoint(x: 12, y: -148),
            control2: CGPoint(x: 10, y: -158)
        )
        return path
    }()

    private static let cob: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -138))
        path.addCurve(
            to: CGPoint(x: 46, y: -56),
            control1: CGPoint(x: 30, y: -138),
            control2: CGPoint(x: 46, y: -100)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: 6),
            control1: CGPoint(x: 46, y: -20),
            control2: CGPoint(x: 28, y: 6)
        )
        path.addCurve(
            to: CGPoint(x: -46, y: -56),
            control1: CGPoint(x: -28, y: 6),
            control2: CGPoint(x: -46, y: -20)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -138),
            control1: CGPoint(x: -46, y: -100),
            control2: CGPoint(x: -30, y: -138)
        )
        path.closeSubpath()
        return path
    }()

    /// 一排一排錯開的玉米粒，鋪滿整根再用玉米的外形裁掉；臉那一圈空下來。
    private static let kernels: Path = {
        var path = Path()
        var isShiftedRow = false
        for rowY in stride(from: CGFloat(-136), through: 6, by: kernelRowGap) {
            let firstX: CGFloat = isShiftedRow ? -58 + kernelColumnGap / 2 : -58
            for columnX in stride(from: firstX, through: 58, by: kernelColumnGap) {
                let distance = hypot(columnX - faceCenter.x, rowY - faceCenter.y)
                if distance >= faceClearRadius {
                    path.addEllipse(in: CGRect(
                        x: columnX - kernelSize.width / 2,
                        y: rowY - kernelSize.height / 2,
                        width: kernelSize.width,
                        height: kernelSize.height
                    ))
                }
            }
            isShiftedRow.toggle()
        }
        return path
    }()

    private static let husks: Path = {
        var path = Path()
        for side: CGFloat in [-1, 1] {
            path.move(to: CGPoint(x: side * 2, y: 8))
            path.addCurve(
                to: CGPoint(x: side * 63, y: -46),
                control1: CGPoint(x: side * 26, y: 13),
                control2: CGPoint(x: side * 52, y: -6)
            )
            path.addCurve(
                to: CGPoint(x: side * 2, y: 8),
                control1: CGPoint(x: side * 44, y: -38),
                control2: CGPoint(x: side * 18, y: -22)
            )
            path.closeSubpath()
        }
        return path
    }()
}
