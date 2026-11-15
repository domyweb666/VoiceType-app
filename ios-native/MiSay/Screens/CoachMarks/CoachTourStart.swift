import SwiftUI
import UIKit

/// 掛在文字稿詳情頁上：標出「正文上半」這個引導目標，第一次打開整理好的文字稿時開始引導；
/// 設定頁按了「重看教學」（引 2）也從這裡開始，這頁已經開著的話 `.task(id:)` 會再跑一次。
/// 規格是進主畫面就開始；米說的首頁只有一顆鈕，要教的東西都在詳情頁，所以改在這裡（提案第二節）。
struct CoachTourStart: ViewModifier {
    let transcript: Transcript
    @Environment(CoachController.self) private var coach: CoachController?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: Token.Coach.bodyTargetHeight)
                    .coachTarget(CoachTour.bodyTarget)
                    .allowsHitTesting(false)
            }
            .task(id: coach?.replayRequests) {
                guard CoachTour.isEligible(transcript), let coach,
                      coach.wantsReplay || !coach.hasCompleted
                else {
                    return
                }
                // 等推入的動畫做完；這頁在那之前就離開的話，sleep 被取消，不開始。
                do {
                    try await Task.sleep(for: Token.Coach.startDelay)
                } catch {
                    return
                }
                // 鍵盤開著會蓋住說明卡，先收起來。
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
                coach.start()
            }
    }
}
