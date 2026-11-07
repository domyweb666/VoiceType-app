import SwiftUI

/// 空清單那根玉米（使用規則第 3 條：可愛只在這裡與收成）。
/// 座標是畫稿本身的 88×112 格，跟著 `Token.Shape.cornWidth／cornHeight` 等比縮放。
struct CornIllustration: View {
    private static let boxWidth: CGFloat = 88
    private static let boxHeight: CGFloat = 112
    private static let kernelRadius: CGFloat = 4
    private static let eyeRadius: CGFloat = 1.8
    private static let smileWidth: CGFloat = 2.5
    private static let kernelCenters: [CGPoint] = [
        CGPoint(x: 34, y: 30),
        CGPoint(x: 54, y: 30),
        CGPoint(x: 44, y: 22),
        CGPoint(x: 30, y: 46),
        CGPoint(x: 44, y: 40),
        CGPoint(x: 58, y: 46),
        CGPoint(x: 32, y: 62),
        CGPoint(x: 44, y: 56),
        CGPoint(x: 56, y: 62),
        CGPoint(x: 36, y: 78),
        CGPoint(x: 44, y: 72),
        CGPoint(x: 52, y: 78),
        CGPoint(x: 44, y: 88),
    ]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.boxWidth, size.height / Self.boxHeight)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let husk = GraphicsContext.Shading.color(CharacterPalette.cornHusk)
            let ink = GraphicsContext.Shading.color(Token.Colors.actionInk)
            context.fill(Self.leftHusk.applying(transform), with: husk)
            context.fill(Self.rightHusk.applying(transform), with: husk)
            context.fill(
                Self.cob.applying(transform),
                with: .color(CharacterPalette.cornKernel)
            )
            context.fill(
                Self.kernels.applying(transform),
                with: .color(CharacterPalette.cornKernelShade)
            )
            context.stroke(
                Self.smile.applying(transform),
                with: ink,
                style: StrokeStyle(lineWidth: Self.smileWidth * scale, lineCap: .round)
            )
            context.fill(Self.eyes.applying(transform), with: ink)
        }
        .frame(width: Token.Shape.cornWidth, height: Token.Shape.cornHeight)
        .accessibilityLabel("一根玉米")
    }

    private static let leftHusk: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 22, y: 70))
        path.addCurve(
            to: CGPoint(x: 8, y: 104),
            control1: CGPoint(x: 12, y: 76),
            control2: CGPoint(x: 6, y: 88)
        )
        path.addCurve(
            to: CGPoint(x: 40, y: 82),
            control1: CGPoint(x: 22, y: 102),
            control2: CGPoint(x: 34, y: 94)
        )
        path.closeSubpath()
        return path
    }()

    private static let rightHusk: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 66, y: 70))
        path.addCurve(
            to: CGPoint(x: 80, y: 104),
            control1: CGPoint(x: 76, y: 76),
            control2: CGPoint(x: 82, y: 88)
        )
        path.addCurve(
            to: CGPoint(x: 48, y: 82),
            control1: CGPoint(x: 66, y: 102),
            control2: CGPoint(x: 54, y: 94)
        )
        path.closeSubpath()
        return path
    }()

    private static let cob: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 44, y: 6))
        path.addCurve(
            to: CGPoint(x: 70, y: 56),
            control1: CGPoint(x: 60, y: 6),
            control2: CGPoint(x: 70, y: 28)
        )
        path.addCurve(
            to: CGPoint(x: 44, y: 100),
            control1: CGPoint(x: 70, y: 82),
            control2: CGPoint(x: 58, y: 100)
        )
        path.addCurve(
            to: CGPoint(x: 18, y: 56),
            control1: CGPoint(x: 30, y: 100),
            control2: CGPoint(x: 18, y: 82)
        )
        path.addCurve(
            to: CGPoint(x: 44, y: 6),
            control1: CGPoint(x: 18, y: 28),
            control2: CGPoint(x: 28, y: 6)
        )
        path.closeSubpath()
        return path
    }()

    private static let kernels: Path = {
        var path = Path()
        for center in kernelCenters {
            path.addEllipse(in: square(around: center, radius: kernelRadius))
        }
        return path
    }()

    private static let eyes: Path = {
        var path = Path()
        path.addEllipse(in: square(around: CGPoint(x: 36, y: 86), radius: eyeRadius))
        path.addEllipse(in: square(around: CGPoint(x: 52, y: 86), radius: eyeRadius))
        return path
    }()

    private static let smile: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 30, y: 96))
        path.addCurve(
            to: CGPoint(x: 58, y: 96),
            control1: CGPoint(x: 34, y: 104),
            control2: CGPoint(x: 54, y: 104)
        )
        return path
    }()

    private static func square(around center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }
}
