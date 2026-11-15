import SwiftUI

/// 聚光燈引導的一步：照亮哪個元件、說明卡寫什麼、玉米人做什麼動作。
/// 整套引導由 `CoachTour.steps` 這個陣列帶，要加減步驟只改陣列（〈聚光燈引導實作規格〉第 3 節）。
struct CoachStep: Identifiable, Equatable {
    let id: String
    /// 要照亮的元件代號，對應畫面上的 `.coachTarget("...")`。
    let targetID: String
    let title: String
    let body: String
    let mascot: StickFigure.Action
    /// 目標是圓形按鈕：洞的圓角用洞高的一半。
    var isRoundTarget = false
}

/// 文字稿詳情頁的引導。五步都在同一頁，不換分頁。
/// 文案是提案 `.vibe/引導與動畫提案.md` 的步驟表，米 2026-11-15 回「ok」；要改字先問米。
enum CoachTour {
    static let bodyTarget = "detail.body"
    static let copyTarget = "detail.copy"
    static let moreTarget = "detail.more"

    /// 錄音整理好的文字稿才帶引導。還沒整理的、自己開的新文稿（鍵盤會自己升起來）不帶。
    static func isEligible(_ transcript: Transcript) -> Bool {
        transcript.draftText != nil && !transcript.isWritten
    }

    /// 「重看教學」要打開哪一篇：清單裡（最新在上）第一篇帶得了引導的。一篇都沒有就是 nil。
    static func replayTranscript(in transcripts: [Transcript]) -> Transcript? {
        transcripts.first(where: isEligible)
    }

    static let steps: [CoachStep] = [
        CoachStep(
            id: "hello",
            targetID: bodyTarget,
            title: "嗨，我是玉米",
            body: "這篇是你剛才講的。花 20 秒，我帶你看這一頁。",
            mascot: .waving
        ),
        CoachStep(
            id: "edit",
            targetID: bodyTarget,
            title: "字可以直接改",
            body: "點一下就能打字，停一秒自動存，不用按儲存。",
            mascot: .pointingUp
        ),
        CoachStep(
            id: "copy",
            targetID: copyTarget,
            title: "複製和分享",
            body: "改好了按這顆複製全文，左邊那顆是分享。",
            mascot: .pointingUp,
            isRoundTarget: true
        ),
        CoachStep(
            id: "more",
            targetID: moreTarget,
            title: "其他功能都在這",
            body: "改寫成其他格式、看 AI 改了什麼、接著錄，都收在這個選單。",
            mascot: .pointingUp,
            isRoundTarget: true
        ),
        CoachStep(
            id: "done",
            targetID: bodyTarget,
            title: "開始吧",
            body: "想再看一次，到設定頁按「重看教學」。",
            mascot: .bowing
        ),
    ]
}
