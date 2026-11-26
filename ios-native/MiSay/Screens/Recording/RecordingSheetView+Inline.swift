import SwiftUI

/// 首頁原地版（2026-11-26 米：錄音時留在這頁，不要彈出視窗）。
/// 錄音中是一顆大圓盤，外面一圈聲波（`RecordingSoundRing`），再點一下圓盤就停；
/// 停了之後的整理、完成、失敗，和被打斷、麥克風被拒，都用跟半頁面板同一套內容，只是長在首頁上。
extension RecordingSheetView {
    /// 內容太高（小手機、完成預覽加按鈕）時可以捲；不高就置中。
    var inlineBody: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Token.Space.xl) {
                    phaseContent
                }
                .padding(.horizontal, Token.Space.xl)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Token.Colors.groupedBackground)
    }

    var inlineRecordingContent: some View {
        VStack(spacing: Token.Space.m) {
            ZStack {
                RecordingSoundRing(recorder: recorder)
                inlineStopButton
            }
            listeningLine
            RecordingTimer(recorder: recorder)
            Text("再點一下結束")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
            markButton
            spaceNote
        }
    }

    /// 錄音中的大圓盤：金棕底、白色圓角方塊（domy：進行中用產品色實心＋方塊），整顆都按得到。
    private var inlineStopButton: some View {
        Button {
            stopRecording()
        } label: {
            RoundedRectangle(cornerRadius: Token.Shape.radiusStopGlyph, style: .continuous)
                .fill(Token.Colors.recordingGlyph)
                .frame(width: Token.Shape.heroStopGlyph, height: Token.Shape.heroStopGlyph)
                .frame(width: Token.Shape.recordDisc, height: Token.Shape.recordDisc)
                .background(Token.Colors.recordingFill, in: Circle())
                .shadow(
                    color: Token.Colors.shadow.opacity(Token.Elevation.recordShadowOpacity),
                    radius: Token.Elevation.recordShadowRadius,
                    y: Token.Elevation.recordShadowY
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("停止錄音")
        .disabled(phase != .recording || isStopping)
    }
}
