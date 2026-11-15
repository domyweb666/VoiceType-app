import SwiftUI

/// `.coachTarget("id")`：讓元件把自己在螢幕上的位置報給 `CoachController`，引導才知道洞要挖在哪。
/// 規格寫的是 `anchorPreference` 往上傳；這裡改成直接量螢幕座標，因為要照的複製鈕與「⋯」在系統導覽列裡，
/// 放在導覽列裡的東西 preference 傳不到根畫面。捲動、旋轉、字級改變時位置照樣會更新。
/// 引導沒在進行時什麼都不量；環境裡沒有 `CoachController`（例如另外升起的頁）也不會出事。
struct CoachTarget: ViewModifier {
    let id: String
    @Environment(CoachController.self) private var coach: CoachController?

    func body(content: Content) -> some View {
        content.background {
            if let coach, coach.isActive {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    Color.clear
                        .onAppear { coach.frames[id] = frame }
                        .onChange(of: frame) { _, moved in coach.frames[id] = moved }
                        .onDisappear { coach.frames[id] = nil }
                }
            }
        }
    }
}

extension View {
    func coachTarget(_ id: String) -> some View {
        modifier(CoachTarget(id: id))
    }
}
