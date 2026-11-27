import SwiftUI

/// 原地版與半頁版的外框（2026-11-26 米：首頁錄音時留在這頁，不要彈出視窗；編輯頁「接著錄」照舊是半頁）。
/// 2026-11-27 B 版之後兩邊的內容是同一套（上半部＋底部托盤），這裡只管兩邊不一樣的地方：
/// 半頁面板矮（只有半個螢幕），聲波用矮的；半頁面板不准下滑關掉（03-線框「錄到一半誤滑就丟掉」）。
extension RecordingSheetView {
    var inlineBody: some View {
        phaseContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Token.Colors.groupedBackground)
    }

    /// 底色跟首頁一樣用米白，白色托盤才看得出來（原本面板是白底）。
    var sheetBody: some View {
        phaseContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, Token.Space.s)
            .background(Token.Colors.groupedBackground)
            .interactiveDismissDisabled()
    }

    /// 聲波高度：首頁上半部空間大，放大當主角；半頁面板只剩一條。
    var waveHeight: CGFloat {
        isInline ? Token.Shape.stageWaveHeight : Token.Shape.primaryTap
    }
}
