import SwiftUI

/// 首頁：米 2026-10-31 鎖定的骨架，正中央超大錄音鈕，其他全搬走。
/// 片 A2 的殼；片 C1 把鈕接上錄音面板（方向 D：點一下升起半頁）；片 C6 的待轉錄列在鈕下方，0 個時整列不出現。
/// 片 C4：出現時先把上次被殺掉留下的救回檔撿進待轉錄。
/// 片 D6：出現時、回到前景時自動續轉待轉錄。
/// 2026-11-02 米：左右滑換頁（`RootPagerView`），首頁不再有「文字稿」「⋯」兩顆鈕；面板的「打開這篇」「去設定」交給外層換頁。
/// 2026-11-07 統一風格：錄音鈕改快門式（`RecordButtonLabel`）、提示改「按中間的鈕」、沒金鑰時鈕上方多一張卡。
struct HomeView: View {
    /// 外層的三頁現在停在首頁。從設定頁滑回來時要重看金鑰在不在。
    let isCurrentPage: Bool
    let onOpenTranscript: (Transcript) -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TranscriptionQueue.self) private var queue
    @Environment(Recorder.self) private var recorder
    @State private var isRecordingSheetShown = false
    @State private var pendingCount = 0
    @State private var hasAPIKey = true

    var body: some View {
        VStack {
            if !hasAPIKey {
                noKeyCard
            }
            // 鈕放在剩下空間的正中央，提示掛在鈕下面、不佔版面。
            // 舊寫法是上下兩個 Spacer、下面那個掛 overlay，真機上下面那個把空間全吃走，鈕被擠到頂（2026-11-08 米截圖）。
            Color.clear
                .overlay { recordButton }
                .overlay { hintBelowButton }
            if pendingCount > 0 {
                pendingRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.Colors.groupedBackground)
        .sheet(isPresented: $isRecordingSheetShown) {
            RecordingSheetView(
                queue: queue,
                recorder: recorder,
                onOpenTranscript: openFromSheet,
                onOpenSettings: openSettingsFromSheet
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(Token.Shape.radiusSheet)
        }
        .task {
            recoverThenReloadPending()
            reloadKey()
            // 不用 .task 自己的工作：推頁時首頁會消失、.task 被取消，整理到一半的那筆會被當成失敗。
            Task { await queue.processPending() }
            EditLearningRunner.start()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else {
                return
            }
            reloadKey()
            Task { await queue.processPending() }
            // 上次沒網路沒學成的修改，回前景再試。
            EditLearningRunner.start()
        }
        .onChange(of: isCurrentPage) { _, isShown in
            if isShown {
                reloadKey()
            }
        }
        .onChange(of: isRecordingSheetShown) { _, shown in
            if !shown {
                reloadPending()
                reloadKey()
            }
        }
        .onChange(of: queue.activity) { _, activity in
            // 背景整理完一筆（或面板收起後才整理完）就重算待轉錄數。
            if activity == .idle {
                reloadPending()
            }
        }
    }

    /// 面板先收起，再請外層換到「文字稿」那頁、推到這一篇。
    private func openFromSheet(_ transcript: Transcript) {
        isRecordingSheetShown = false
        onOpenTranscript(transcript)
    }

    private func openSettingsFromSheet() {
        isRecordingSheetShown = false
        onOpenSettings()
    }

    /// 首頁每次出現（含從別頁返回）都會跑。正在錄的檔也放在救回資料夾裡，
    /// 撿走就會被轉錄、刪掉，後面講的話全沒了，所以錄音中不撿（組塊 S 片 S5）。
    private func recoverThenReloadPending() {
        if !recorder.isRecording {
            // 撿不回來不擋首頁：檔還留在原地，下次再試。
            _ = try? PendingRecordings().recoverAbandonedRecordings()
        }
        reloadPending()
    }

    private func reloadPending() {
        // 讀不到清單時列就不出現；進清單頁會看到讀取失敗的字。
        pendingCount = (try? PendingRecordings().list().count) ?? 0
    }

    /// 讀不到 Keychain 就當沒金鑰：卡片多出現一次不傷人，設定頁會講讀取失敗。
    private func reloadKey() {
        let key = (try? APIKeyStore().read()) ?? ""
        hasAPIKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// 首頁的四塊：沒金鑰的卡、錄音鈕、提示、待轉錄列。
private extension HomeView {
    @ViewBuilder
    var recordButton: some View {
        let button = Button {
            isRecordingSheetShown = true
        } label: {
            RecordButtonLabel()
        }
        .accessibilityLabel("開始錄音")

        // 減少動態時不縮放，用系統預設的按壓回饋（變淡）。
        if reduceMotion {
            button
        } else {
            button.buttonStyle(RecordButtonStyle())
        }
    }

    /// 06-首次體驗：金鑰橫幅在鈕上方。整張可點，去設定頁。
    var noKeyCard: some View {
        Button(action: onOpenSettings) {
            HStack(spacing: Token.Space.m) {
                Image(systemName: "key.fill")
                    .font(Token.Fonts.icon)
                    .foregroundStyle(Token.Colors.link)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text("還沒有金鑰")
                        .font(Token.Fonts.rowTitle)
                        .foregroundStyle(Token.Colors.textPrimary)
                    Text("沒金鑰也能錄，錄完先收在待轉錄。貼上金鑰後會自動整理。")
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Token.Colors.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(Token.Space.l)
            .background(
                Token.Colors.rowBackground,
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Token.Space.l)
        .padding(.top, Token.Space.s)
    }

    /// 提示的上緣對齊正中央，再往下推半顆鈕，剛好接在鈕下方。
    var hintBelowButton: some View {
        firstTimeHint
            .padding(.top, Token.Shape.recordTap / 2)
            .alignmentGuide(VerticalAlignment.center) { $0[.top] }
    }

    var firstTimeHint: some View {
        VStack(spacing: Token.Space.s) {
            Text("按中間的鈕，說一段話")
                .font(Token.Fonts.rowTitle)
                .foregroundStyle(Token.Colors.textPrimary)
            Text("說完會變成可以直接貼上的文字，自動幫你複製。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, Token.Space.xl)
        .padding(.horizontal, Token.Space.xl)
    }

    /// 待轉錄列（03-線框首頁 D）：整列可點，推入待轉錄清單。
    var pendingRow: some View {
        NavigationLink {
            PendingListView(onChange: reloadPending)
        } label: {
            HStack(spacing: Token.Space.m) {
                VStack(alignment: .leading, spacing: Token.Space.xs) {
                    Text("待轉錄 \(pendingCount) 個")
                        .font(Token.Fonts.rowTitle)
                        .foregroundStyle(Token.Colors.textPrimary)
                    Text("沒網路或沒金鑰時收在這裡，不會丟")
                        .font(Token.Fonts.secondary)
                        .foregroundStyle(Token.Colors.textSecondary)
                }
                // 按鈕裡的字預設置中，第二行會跑到中間（2026-11-02 米真機截圖）。
                .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Token.Colors.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(Token.Space.l)
            .background(
                Token.Colors.rowBackground,
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow)
            )
        }
        // iOS 26 會替 NavigationLink 套一層灰色的系統按鈕底，比白卡片大一圈、看起來像被蓋住；
        // 卡片自己有底，關掉系統那層（2026-11-02 米真機截圖）。
        .buttonStyle(.plain)
        .padding(.horizontal, Token.Space.l)
        .padding(.bottom, Token.Space.l)
    }
}

/// 按下去縮一下（2-4 回饋）。只在沒開「減少動態」時用。
private struct RecordButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Token.Motion.recordPressScale : 1)
            .animation(Token.Motion.recordPress(false), value: configuration.isPressed)
    }
}
