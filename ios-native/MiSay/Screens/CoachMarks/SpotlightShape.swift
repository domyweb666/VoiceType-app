import SwiftUI

/// 黑幕：整片填滿，中間挖一個圓角矩形的洞（用 even-odd 規則填色）。
/// 洞的 x、y、寬、高都能做動畫，換步驟時洞才會滑過去，不是瞬間跳過去。
struct SpotlightShape: Shape {
    typealias Pair = AnimatablePair<CGFloat, CGFloat>

    var hole: CGRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<Pair, Pair> {
        get {
            AnimatablePair(Pair(hole.minX, hole.minY), Pair(hole.width, hole.height))
        }
        set {
            hole = CGRect(
                x: newValue.first.first,
                y: newValue.first.second,
                width: newValue.second.first,
                height: newValue.second.second
            )
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        // 洞還在長大的時候圓角不能比洞的一半大，不然形狀會破。
        let radius = min(cornerRadius, min(hole.width, hole.height) / 2)
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius))
        return path
    }
}
