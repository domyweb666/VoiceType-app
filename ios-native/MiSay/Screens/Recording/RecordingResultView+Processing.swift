import SwiftUI

/// 整理中（B3，2026-11-27）：大標「整理中…」，下面一張白卡，「轉成文字」一段畫一格，下面一行「潤飾」。
/// 只畫流水真的回報得到的：轉到第幾段、是不是在潤飾。
/// 一段裡面轉了幾成不知道，所以正在轉的那格整格畫半透明金棕，不畫假的百分比。
extension RecordingResultView {
    var processingStage: some View {
        let name = recordingURL.lastPathComponent
        let activity = queue.activity
        let cells = Self.transcriptionCells(
            for: activity,
            recording: name,
            knownTotal: segmentTotal
        )
        let isPolishing = Self.isPolishing(activity, recording: name)
        let segment = Self.segmentText(for: activity, recording: name)
        return Group {
            VStack(alignment: .leading, spacing: Token.Space.s) {
                Text("整理中…")
                    .font(titleFont)
                    .foregroundStyle(Token.Colors.textPrimary)
                // S2-8：原本「先放著」聽起來像放著就會好，其實鎖屏太久會停。照實講。
                Text("收起來也會繼續整理；鎖屏太久會先停，回到芋音接著做。")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                gapLine
            }
            progressCard(cells: cells, segment: segment, isPolishing: isPolishing)
            if showsCostNotice {
                costNotice
            }
        }
    }

    /// 第一次整理才出現：灰底小字，不搶「整理中」的版面。
    private var costNotice: some View {
        Text("錄音會送到 OpenAI 轉成文字，費用算在你的金鑰上")
            .font(Token.Fonts.footnote)
            .foregroundStyle(Token.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Token.Space.l)
            .padding(.vertical, Token.Space.m)
            .background(
                Token.Colors.sunkenBackground,
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusField, style: .continuous)
            )
    }

    private func progressCard(
        cells: [ProgressCell],
        segment: String?,
        isPolishing: Bool
    ) -> some View {
        let allDone = cells.allSatisfy { $0 == .done }
        return VStack(alignment: .leading, spacing: Token.Space.l) {
            progressRow(
                title: "轉成文字",
                detail: allDone ? "轉好了" : segment,
                isDetailActive: !allDone,
                cells: cells
            )
            Rectangle()
                .fill(Token.Colors.separator)
                .frame(height: Token.Shape.hairline)
                .accessibilityHidden(true)
            progressRow(
                title: "潤飾",
                detail: isPolishing ? "潤飾中" : "轉完才開始",
                isDetailActive: isPolishing,
                cells: [isPolishing ? .working : .waiting]
            )
        }
        .padding(Token.Space.screen)
        .background(
            Token.Colors.rowBackground,
            in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow, style: .continuous)
        )
    }

    /// 一行標題＋右邊狀態字，下面一排格子。讀屏唸「轉成文字，第 2／3 段」，格子不唸。
    private func progressRow(
        title: String,
        detail: String?,
        isDetailActive: Bool,
        cells: [ProgressCell]
    ) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.m) {
            HStack(alignment: .firstTextBaseline, spacing: Token.Space.s) {
                Text(title)
                    .font(Token.Fonts.rowTitle)
                    .foregroundStyle(Token.Colors.textPrimary)
                Spacer(minLength: Token.Space.s)
                if let detail {
                    Text(detail)
                        .font(Token.Fonts.secondary.weight(isDetailActive ? .semibold : .regular))
                        .foregroundStyle(
                            isDetailActive ? Token.Colors.link : Token.Colors.textSecondary
                        )
                }
            }
            HStack(spacing: Token.Space.xs) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    Capsule()
                        .fill(Self.color(for: cell))
                        .frame(height: Token.Shape.progressBarHeight)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail.map { "\(title)，\($0)" } ?? title)
    }

    private static func color(for cell: ProgressCell) -> Color {
        switch cell {
        case .done:
            Token.Colors.accent
        case .working:
            Token.Colors.accent.opacity(Token.Halo.workingCellOpacity)
        case .waiting:
            Token.Colors.sunkenBackground
        }
    }
}
