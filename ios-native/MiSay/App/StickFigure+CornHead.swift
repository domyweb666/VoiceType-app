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

    static func drawCornHead(eyeHeight: CGFloat, in context: GraphicsContext) {
        let shade = GraphicsContext.Shading.color(CharacterPalette.cornKernelShade)
        let ink = GraphicsContext.Shading.color(Token.Colors.actionInk)
        let roundLine = StrokeStyle(lineWidth: silkWidth, lineCap: .round)
        context.stroke(silk, with: shade, style: roundLine)
        context.fill(cob, with: .color(CharacterPalette.cornKernel))
        var insideCob = context
        insideCob.clip(to: cob)
        insideCob.fill(kernels, with: shade)
        context.fill(husks, with: .color(CharacterPalette.cornHusk))
        context.fill(eyes(height: eyeHeight), with: ink)
        context.stroke(
            browsAndSmile,
            with: ink,
            style: StrokeStyle(lineWidth: faceLineWidth, lineCap: .round)
        )
    }

    private static func eyes(height: CGFloat) -> Path {
        var path = Path()
        for side: CGFloat in [-1, 1] {
            let eye = CGRect(
                x: side * eyeOffsetX - eyeWidth / 2,
                y: eyeCenterY - height / 2,
                width: eyeWidth,
                height: height
            )
            path.addRoundedRect(
                in: eye,
                cornerSize: CGSize(width: eyeWidth / 2, height: min(eyeWidth, height) / 2)
            )
        }
        return path
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

    /// 兩道眉毛（外側稍微往上）加一個微笑。
    private static let browsAndSmile: Path = {
        var path = Path()
        path.move(to: CGPoint(x: -20, y: -61.3))
        path.addLine(to: CGPoint(x: -4, y: -60.7))
        path.move(to: CGPoint(x: 4, y: -60.7))
        path.addLine(to: CGPoint(x: 20, y: -61.3))
        path.move(to: CGPoint(x: -6, y: -31))
        path.addQuadCurve(to: CGPoint(x: 6, y: -31), control: CGPoint(x: 0, y: -25))
        return path
    }()
}
