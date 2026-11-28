import SwiftUI

/// 「請 AI 看整篇」那張頁。2026-11-28 米選設計稿 R-C「意見標在稿子上」：
/// 整張頁是唯讀的稿子（`ReviewSheet+Manuscript`），卡住的句子塗金加編號、AI 看的開頭框起來；
/// 下面白色托盤一次講一條、左右翻（`ReviewSheet+Tray`、`+Results`）。要改字才按「到編輯頁改這句」收起這頁、跳過去。
/// 送出在詳情頁（`TranscriptDetailView+Review`），這張頁收起來照樣看完；意見當純文字顯示（安全標準五）。
struct ReviewSheet: View {
    /// 這次打開這篇問到的意見。每種只留最近一次。
    struct Session {
        private(set) var results: [ReviewResult] = []
        var runningKind: ReviewKind?
        var failure: String?
        var task: Task<Void, Never>?

        mutating func add(_ result: ReviewResult) {
            results.removeAll { $0.kind == result.kind }
            results.insert(result, at: 0)
        }
    }

    /// 稿子上的捲動錨點：最上面（標題、開頭），或某一段。
    enum ManuscriptAnchor: Hashable {
        case top
        case paragraph(Int)
    }

    let session: Session
    /// 現在的文字稿：引文照它找位置。
    let text: String
    let currentTitle: String?
    let onReview: (ReviewKind) -> Void
    let onCancel: () -> Void
    let onPickTitle: (String) -> Void
    let onJump: (Range<Int>) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    /// 托盤在講哪一種；nil 是還沒選，托盤列出三種讓人挑。
    @State var shownKind: ReviewKind?
    /// `session.failure` 只有一格，記下是按哪一種按出來的：切到別種就不該看到上一種的失敗。
    @State var failureKind: ReviewKind?
    /// 開頭、卡在哪翻到第幾條（從 0 起）。
    @State var pointIndex = 0

    static let costNote = "只給意見，不會改你的稿。每按一次，會用到一點 OpenAI 的費用。"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: .zero) {
                    ScrollView {
                        manuscript
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    tray
                }
                .background(Token.Colors.groupedBackground)
                .onChange(of: scrollAnchor) { _, anchor in
                    scroll(proxy, to: anchor)
                }
            }
            .navigationTitle("請 AI 看整篇")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .tint(Token.Colors.link)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
        .onAppear(perform: restoreKind)
        .onChange(of: session.results) {
            pointIndex = 0
        }
    }

    /// 正在看的那種優先（頁面關掉再打開也一樣），看完才換回米點的那種。
    var activeKind: ReviewKind? {
        session.runningKind ?? shownKind
    }

    var visibleFailure: String? {
        guard failureKind == activeKind else {
            return nil
        }
        return session.failure
    }

    func result(for kind: ReviewKind) -> ReviewResult? {
        session.results.first { $0.kind == kind }
    }

    /// 卡在哪的每一處加上在現在稿子裡的位置；翻頁順序是找得到位置的在前（`ReviewResult.locate`）。
    var locatedPoints: [LocatedStuckPoint] {
        guard case let .stuck(points)? = result(for: .stuck) else {
            return []
        }
        return ReviewResult.locate(points, in: text)
    }

    /// 送出跟原本一樣交給詳情頁；這裡只記托盤要停在哪一種。
    func send(_ kind: ReviewKind) {
        shownKind = kind
        failureKind = kind
        pointIndex = 0
        onReview(kind)
    }

    func show(_ kind: ReviewKind) {
        shownKind = kind
        pointIndex = 0
    }

    func pickTitle(_ title: String) {
        failureKind = .titles
        onPickTitle(title)
    }

    /// 頁面每次打開都重來：還在看就停在那種；上次失敗了就列三種、把原因講在那裡；不然打開最近看好的那種。
    private func restoreKind() {
        if let running = session.runningKind {
            shownKind = running
            failureKind = running
        } else if session.failure == nil {
            shownKind = session.results.first?.kind
        }
    }

    /// 翻到下一處時把那一句捲到畫面中間；減少動態時換成短的淡入淡出，不是關掉。
    private func scroll(_ proxy: ScrollViewProxy, to anchor: ManuscriptAnchor?) {
        guard let anchor else {
            return
        }
        withAnimation(Token.Motion.sheetRise(reduceMotion)) {
            proxy.scrollTo(anchor, anchor: anchor == .top ? .top : .center)
        }
    }

    // MARK: 托盤共用的小零件

    func note(_ text: String) -> some View {
        Text(text)
            .font(Token.Fonts.footnote)
            .foregroundStyle(Token.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 狀態條本身有內距；托盤已經是白底，往左右拉回去，字才跟托盤裡其他字對齊。
    func statusLine(_ glyph: StatusStrip.Glyph, _ message: String) -> some View {
        StatusStrip(glyph: glyph, message: message)
            .padding(.horizontal, -Token.Space.l)
    }

    var separator: some View {
        Rectangle()
            .fill(Token.Colors.separator)
            .frame(height: Token.Shape.hairline)
            .accessibilityHidden(true)
    }

    func shortTitle(_ kind: ReviewKind) -> String {
        switch kind {
        case .titles: "下標題"
        case .opening: "開頭"
        case .stuck: "卡在哪"
        }
    }

    func runningText(_ kind: ReviewKind) -> String {
        switch kind {
        case .titles: "正在下標題，長的稿子要等一下"
        case .opening: "正在看開頭夠不夠力，長的稿子要等一下"
        case .stuck: "正在看讀者會卡在哪，長的稿子要等一下"
        }
    }

    func symbolName(_ kind: ReviewKind) -> String {
        switch kind {
        case .titles: "textformat"
        case .opening: "text.alignleft"
        case .stuck: "text.magnifyingglass"
        }
    }
}
