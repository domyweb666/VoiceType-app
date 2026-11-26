import SwiftUI
import VeggieKit

/// 米說震動的唯一入口（準則 3-42）：設定頁「觸覺回饋」關掉就不震。
/// 直接掛 `.sensoryFeedback` 不會看那個開關，所以畫面一律改掛這兩個；關掉時回傳 nil，系統就不震。
extension View {
    func sensoryFeedbackIfEnabled(
        _ feedback: SensoryFeedback,
        trigger: some Equatable
    ) -> some View {
        sensoryFeedback(trigger: trigger) { _, _ in
            VeggieHaptics.isEnabled ? feedback : nil
        }
    }

    func sensoryFeedbackIfEnabled<Trigger: Equatable>(
        trigger: Trigger,
        _ feedback: @escaping (Trigger, Trigger) -> SensoryFeedback?
    ) -> some View {
        sensoryFeedback(trigger: trigger) { old, new in
            VeggieHaptics.isEnabled ? feedback(old, new) : nil
        }
    }
}
