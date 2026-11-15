import SwiftUI

/// 引導的說明卡：左邊玉米人，右邊進度小點、標題、內文、「知道了」。內文一個字一個字打出來。
/// 按「知道了」：字還在打就先整段顯示，已經顯示完才到下一步。
/// 減少動態時不打字，直接整段出現。讀屏一次唸「第 N 步，共 M 步」加標題與全文，不逐字唸。
struct CoachCard: View {
    let step: CoachStep
    let index: Int
    let count: Int
    let onNext: () -> Void

    /// 這些標點後面多停一下。
    static let pausingPunctuation: Set<Character> = ["，", "。", "、", "！", "？", "；", "："]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typedCount = 0
    @State private var showsAll = false
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Token.Space.m) {
            StickFigure(action: step.mascot, isCompact: true)
            VStack(alignment: .leading, spacing: Token.Space.s) {
                words
                Button(action: advance) {
                    Text("知道了")
                        .font(Token.Fonts.rowTitle)
                        .foregroundStyle(Token.Colors.onAccent)
                        .padding(.horizontal, Token.Space.l)
                        .frame(height: Token.Coach.buttonHeight)
                        .background(Token.Colors.accent, in: Capsule())
                        .frame(minHeight: Token.Shape.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(Token.Space.l)
        .background(
            Token.Colors.rowBackground,
            in: RoundedRectangle(cornerRadius: Token.Coach.cardRadius)
        )
        .task(id: step.id) { await typeOut() }
    }

    /// 打字機每個字之後停多久。
    static func delay(after character: Character) -> Duration {
        pausingPunctuation.contains(character)
            ? Token.Coach.typeInterval + Token.Coach.typePause
            : Token.Coach.typeInterval
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: Token.Space.s) {
            dots
            Text(step.title)
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            // 字級放到最大時內文可能比卡片高：放得下就直接放，放不下才包成可捲的。
            ViewThatFits(in: .vertical) {
                bodyText
                ScrollView { bodyText }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(index + 1) 步，共 \(count) 步。\(step.title)。\(step.body)")
        .accessibilityFocused($isFocused)
    }

    /// 先用整段（看不見的）把位置佔好，上面疊打到一半的字，卡片才不會邊打邊長高。
    private var bodyText: some View {
        Text(step.body)
            .hidden()
            .overlay(alignment: .topLeading) {
                Text(showsAll ? step.body : String(step.body.prefix(typedCount)))
            }
            .font(Token.Fonts.secondary)
            .foregroundStyle(Token.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dots: some View {
        HStack(spacing: Token.Coach.dotGap) {
            ForEach(0 ..< count, id: \.self) { position in
                Capsule()
                    .fill(position == index ? Token.Colors.accent : Token.Colors.separator)
                    .frame(
                        width: position == index ? Token.Coach.dotCurrent : Token.Coach.dot,
                        height: Token.Coach.dot
                    )
            }
        }
    }

    private func advance() {
        if showsAll {
            onNext()
        } else {
            showsAll = true
        }
    }

    /// 這一步的卡出現時跑一次；換步驟、卡片消失時 `.task` 取消，迴圈跟著停。
    private func typeOut() async {
        isFocused = true
        guard !reduceMotion else {
            showsAll = true
            return
        }
        for character in step.body {
            if showsAll {
                return
            }
            typedCount += 1
            do {
                try await Task.sleep(for: Self.delay(after: character))
            } catch {
                return
            }
        }
        showsAll = true
    }
}
