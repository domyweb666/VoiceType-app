import SwiftUI

/// 鍵盤上方那一排（2026-11-24 抽出來，兩種編輯框共用）：左邊格式可以橫滑，右邊「在這裡接著錄」「改這段」固定。
/// 格式只插 Markdown 記號（`MarkdownFormatting`），文字稿還是純文字。圖示配無障礙標籤，不只靠圖。
struct FormatBar<PassageMenu: View>: View {
    let canRecordHere: Bool
    let onFormat: ((String, Range<Int>) -> MarkdownFormatting.Edit) -> Void
    let onLink: () -> Void
    let onRecordHere: () -> Void
    @ViewBuilder let passageMenu: () -> PassageMenu

    var body: some View {
        HStack(spacing: Token.Space.m) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Token.Space.xs) {
                    ForEach(MarkdownFormatting.LineMark.allCases) { mark in
                        button(mark.title, systemImage: mark.systemImage) {
                            onFormat { MarkdownFormatting.toggle(mark, in: $0, selection: $1) }
                        }
                    }
                    button("粗體", systemImage: "bold") {
                        onFormat { MarkdownFormatting.toggleBold(in: $0, selection: $1) }
                    }
                    button("連結", systemImage: "link", action: onLink)
                }
            }
            // 編輯框底下的留白會傳到這裡，不歸零整排格式鈕會往上浮出去。
            .contentMargins(.bottom, 0, for: .scrollContent)
            button("在這裡接著錄", systemImage: "mic.badge.plus", action: onRecordHere)
                .disabled(!canRecordHere)
            passageMenu()
        }
        .font(Token.Fonts.rowTitle)
        .tint(Token.Colors.link)
        .padding(.horizontal, Token.Space.m)
        .frame(height: Token.Shape.minTap)
        .background(Token.Colors.groupedBackground)
    }

    private func button(
        _ label: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(minWidth: Token.Shape.minTap, minHeight: Token.Shape.minTap)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

extension MarkdownFormatting.LineMark {
    var title: String {
        switch self {
        case .heading: "標題"
        case .subheading: "小標"
        case .list: "清單"
        case .numbered: "編號清單"
        case .quote: "引言"
        }
    }

    /// 不用 textformat 那一系列：中文系統會換成中文字。
    var systemImage: String {
        switch self {
        case .heading: "number"
        case .subheading: "number.square"
        case .list: "list.bullet"
        case .numbered: "list.number"
        case .quote: "text.quote"
        }
    }
}
