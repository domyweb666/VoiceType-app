import SwiftUI

/// R-C 下半部的白色托盤：還沒選就列三種；選了上面是三種的切換膠囊，下面是看稿中、失敗、還沒問或結果。
/// 托盤太高（字放大、小手機）時自己捲，上面的稿子至少留一半（VStack 平分給兩邊）。
/// 送出前擋下、標題沒存進去、送出失敗都用狀態條講，跟其他畫面同一套。
extension ReviewSheet {
    var tray: some View {
        ViewThatFits(in: .vertical) {
            trayContent
            ScrollView {
                trayContent
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, Token.Space.screen)
        .padding(.top, Token.Space.l)
        .padding(.bottom, Token.Space.s)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: Token.Shape.radiusTray,
                topTrailingRadius: Token.Shape.radiusTray,
                style: .continuous
            )
            .fill(Token.Colors.rowBackground)
            .shadow(
                color: Token.Colors.shadow.opacity(Token.Elevation.trayShadowOpacity),
                radius: Token.Elevation.trayShadowRadius,
                y: -Token.Elevation.trayShadowY
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var trayContent: some View {
        VStack(alignment: .leading, spacing: Token.Space.m) {
            if let kind = activeKind {
                kindTabs(active: kind)
                kindContent(kind)
            } else {
                chooser
            }
        }
    }

    // MARK: 還沒選（設計稿 R-C1）

    @ViewBuilder
    private var chooser: some View {
        Text("要 AI 看哪一樣？")
            .font(Token.Fonts.secondary.weight(.semibold))
            .foregroundStyle(Token.Colors.textPrimary)
        VStack(spacing: .zero) {
            ForEach(ReviewKind.allCases) { kind in
                if kind != ReviewKind.allCases.first {
                    separator
                }
                chooserRow(kind)
            }
        }
        if let failure = visibleFailure {
            statusLine(.failed, failure)
        }
        note(Self.costNote)
    }

    /// 看過的那種點了只是打開結果，不會再送一次（再送要按結果上面的「再看一次」）。
    private func chooserRow(_ kind: ReviewKind) -> some View {
        let hasResult = result(for: kind) != nil
        return Button {
            if hasResult {
                show(kind)
            } else {
                send(kind)
            }
        } label: {
            HStack(spacing: Token.Space.m) {
                Image(systemName: symbolName(kind))
                    .font(Token.Fonts.secondary.weight(.semibold))
                    .foregroundStyle(Token.Colors.link)
                    .frame(
                        width: Token.Shape.reviewKindCircle,
                        height: Token.Shape.reviewKindCircle
                    )
                    .background(Token.Colors.accentSoft, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text(kind.title)
                        .font(Token.Fonts.rowTitle)
                        .foregroundStyle(Token.Colors.textPrimary)
                    Text(hasResult ? "看過了，點了看意見" : kind.summary)
                        .font(Token.Fonts.footnote)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Token.Space.s)
                Image(systemName: "chevron.right")
                    .font(Token.Fonts.footnote.weight(.semibold))
                    .foregroundStyle(Token.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Token.Space.s)
            .frame(minHeight: Token.Shape.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 選了一種（設計稿 R-C2～R-C6）

    /// 看稿中不能切（一次只看一種），正在看的那顆照樣亮著。
    private func kindTabs(active: ReviewKind) -> some View {
        HStack(spacing: Token.Space.s) {
            ForEach(ReviewKind.allCases) { kind in
                kindTab(kind, isActive: kind == active)
            }
        }
    }

    private func kindTab(_ kind: ReviewKind, isActive: Bool) -> some View {
        let hasResult = result(for: kind) != nil
        let isEnabled = session.runningKind == nil
        return Button {
            show(kind)
        } label: {
            HStack(spacing: Token.Space.xs) {
                Text(shortTitle(kind))
                if hasResult {
                    Circle()
                        .frame(width: Token.Shape.reviewDot, height: Token.Shape.reviewDot)
                        .accessibilityHidden(true)
                }
            }
            .font(Token.Fonts.secondary.weight(.semibold))
            .foregroundStyle(isActive ? Token.Colors.onAccent : Token.Colors.link)
            .frame(maxWidth: .infinity, minHeight: Token.Shape.minTap)
            .background(isActive ? Token.Colors.accent : Token.Colors.accentSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isActive ? 1 : Token.Motion.buttonOpacity(isEnabled: isEnabled, isPressed: false))
        .accessibilityLabel(kind.title)
        .accessibilityValue(hasResult ? "有結果" : "")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder
    private func kindContent(_ kind: ReviewKind) -> some View {
        if session.runningKind == kind {
            runningRow(kind)
            note(kind == .titles ? "看完列在這裡，點一個就設成標題。" : "看完會直接標在上面的稿子裡。")
        } else {
            if let failure = visibleFailure {
                statusLine(.failed, failure)
            }
            if let found = result(for: kind) {
                resultContent(found)
            } else {
                askContent(kind)
            }
        }
    }

    /// 停止鈕放在轉圈那一行旁邊（以前在左上角，離太遠）。
    private func runningRow(_ kind: ReviewKind) -> some View {
        HStack(spacing: Token.Space.s) {
            ProgressView()
                .tint(Token.Colors.link)
            Text(runningText(kind))
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textPrimary)
            Spacer(minLength: Token.Space.s)
            Button(action: onCancel) {
                Text("停止")
                    .font(Token.Fonts.secondary.weight(.semibold))
                    .foregroundStyle(Token.Colors.link)
                    .padding(.horizontal, Token.Space.l)
                    .frame(minHeight: Token.Shape.minTap)
                    .background(Token.Colors.rowBackground, in: Capsule())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("停止看稿")
        }
        .padding(.leading, Token.Space.l)
        .padding(.trailing, Token.Space.xs)
        .padding(.vertical, Token.Space.xs)
        .background(
            Token.Colors.accentTint,
            in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Token.Shape.radiusRow, style: .continuous)
                .strokeBorder(Token.Colors.accentSoft, lineWidth: Token.Shape.hairline)
        }
    }

    /// 還沒問過這種、或上次沒看成。失敗時同一顆鈕改叫「再試一次」（設計稿 R-C6）。
    @ViewBuilder
    private func askContent(_ kind: ReviewKind) -> some View {
        Text(kind.summary)
            .font(Token.Fonts.secondary)
            .foregroundStyle(Token.Colors.textSecondary)
        Button {
            send(kind)
        } label: {
            if visibleFailure == nil {
                Text("請 AI 看")
            } else {
                Label("再試一次", systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        note(Self.costNote)
    }
}
