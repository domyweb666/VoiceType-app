import SwiftUI
import UIKit

/// 掛在文字稿詳情頁上：標出「正文上半」這個引導目標，第一次打開整理好的文字稿時開始引導。
/// 規格是進主畫面就開始；米說的首頁只有一顆鈕，要教的東西都在詳情頁，所以改在這裡（提案第二節）。
struct CoachTourStart: ViewModifier {
    let transcript: Transcript
    @Environment(CoachController.self) private var coach: CoachController?

    /// 錄音整理好的文字稿才帶。還沒整理的、自己開的新文稿（鍵盤會自己升起來）不帶。
    private var isEligible: Bool {
        transcript.draftText != nil && !transcript.isWritten
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: Token.Coach.bodyTargetHeight)
                    .coachTarget(CoachTour.bodyTarget)
                    .allowsHitTesting(false)
            }
            .task {
                guard isEligible, let coach, !coach.hasCompleted else {
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
                coach.startIfFirstTime()
            }
    }
}
