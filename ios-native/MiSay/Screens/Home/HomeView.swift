import SwiftUI

/// 首頁：米 2026-10-31 鎖定的骨架，正中央超大錄音鈕，其他全搬走。
/// 片 A2 的殼；片 C1 把鈕接上錄音面板（方向 D：點一下升起半頁）；片 C6 的待轉錄列在鈕下方，0 個時整列不出現。
/// 片 C4：出現時先把上次被殺掉留下的救回檔撿進待轉錄。
/// 片 D6：出現時、回到前景時自動續轉待轉錄。
/// 2026-11-02 米：左右滑換頁（11/08 改成底部分頁列 `RootTabView`），首頁不再有「文字稿」「⋯」兩顆鈕；面板的「打開這篇」「去設定」交給外層換頁。
/// 2026-11-07 統一風格：錄音鈕改快門式（`RecordButtonLabel`）、提示改「按中間的鈕」、沒金鑰時鈕上方多一張卡。
/// 2026-11-09 米：提示改成長錄音的講法。
/// 2026-11-14 照 domy-design 的錄音畫面：提示第一行升一級、左右邊距 20。
/// 2026-11-24 主力編輯器：上緣那行口述統計拿掉，只留在設定頁。
/// 2026-11-26 米：錄音不彈窗，按下去這頁原地換成錄音中（`RecordingSheetView` 傳 `onClose` 的原地版）；
/// 待機的鈕後面加呼吸光暈（`RecordHalo`）。
/// 2026-11-27 米選錄音畫面 B 版「上面看、下面按」：待機也照錄音中的排法，上半部大標、灰的 00:00 與平的聲波，
/// 錄音鈕縮小收進底部托盤（`RecordingTrayLayout`）；待轉錄改成大標右邊的膠囊。系統導覽列藏起來，大標自己畫。
struct HomeView: View {
    /// 外層的三頁現在停在首頁。從設定頁滑回來時要重看金鑰在不在。
    let isCurrentPage: Bool
    let onOpenTranscript: (Transcript) -> Void
    let onOpenSettings: () -> Void
    /// 有人要開錄，面板要從首頁升起來，先切過來。
    let onShowHome: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TranscriptionQueue.self) private var queue
    @Environment(Recorder.self) private var recorder
    /// 這頁現在是錄音那一套（錄音中、整理中、完成…），不是待機的大鈕。
    @State private var isRecordingShown = false
    @State private var pendingCount = 0
    @State private var hasAPIKey = true

    var body: some View {
        ZStack {
            if isRecordingShown {
                RecordingSheetView(
                    queue: queue,
                    recorder: recorder,
                    onOpenTranscript: openFromSheet,
                    onOpenSettings: openSettingsFromSheet,
                    onClose: { isRecordingShown = false }
                )
                .transition(.opacity)
            } else {
                idleContent
                    .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: Token.Motion.modeSwitch),
            value: isRecordingShown
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.Colors.groupedBackground)
        // 大標「錄音」和待轉錄膠囊同一行，系統的導覽列只會多空一塊；推進待轉錄清單時那頁有自己的導覽列。
        .toolbar(.hidden, for: .navigationBar)
        // K1：捷徑、Siri、控制中心丟來的開錄請求（接著錄走文字稿頁自己的面板）。冷啟動時請求在畫面出來前就到了，onAppear 補。
        .onAppear { takeRecordingRequest() }
        .onChange(of: RecordingLauncher.shared.request) { _, _ in takeRecordingRequest() }
        // 留著的請求，等開著的錄音面板（首頁的、文字稿頁的）收掉才開。
        .onChange(of: RecordingLauncher.shared.hasOpenPanel) { _, _ in takeRecordingRequest() }
        .task {
            recoverThenReloadPending()
            reloadKey()
            queue.startPendingRun()
            CorrectedWordsRunner.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                queue.noteBackgrounded()
            }
            guard phase == .active else {
                return
            }
            reloadKey()
            queue.returnedToForeground()
        }
        .onChange(of: isCurrentPage) { _, isShown in
            if isShown {
                reloadKey()
            }
        }
        .onChange(of: isRecordingShown) { _, shown in
            if !shown {
                reloadPending()
                reloadKey()
                takeRecordingRequest()
            }
        }
        .onChange(of: queue.activity) { _, activity in
            // 背景整理完一筆（或面板收起後才整理完）就重算待轉錄數。
            if activity == .idle {
                reloadPending()
            }
        }
    }

    /// 正在錄就不理：一次只錄一段。停在上一段的完成面板時先留著，不收掉使用者正在看的。
    private func takeRecordingRequest() {
        let taken = RecordingLauncher.shared.take(
            isRecording: recorder.isRecording,
            isPanelOpening: isRecordingShown
        )
        guard taken != nil else {
            return
        }
        onShowHome()
        isRecordingShown = true
    }

    /// 面板先收起，再請外層換到「文字稿」那頁、推到這一篇。
    private func openFromSheet(_ transcript: Transcript) {
        isRecordingShown = false
        onOpenTranscript(transcript)
    }

    private func openSettingsFromSheet() {
        isRecordingShown = false
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

/// 首頁待機（B1）：上半部大標與待轉錄膠囊、沒金鑰的卡、灰的計時與聲波；托盤裡是錄音鈕。
private extension HomeView {
    var idleContent: some View {
        RecordingTrayLayout {
            titleRow
            if !hasAPIKey {
                noKeyCard
            }
            VStack(alignment: .leading, spacing: Token.Space.s) {
                RecordingTimer(recorder: nil, isDimmed: true)
                Text("按下面的鈕開始，講多久都可以，講完會整理成文字稿。")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
            RecordingWaveform(recorder: nil)
        } tray: {
            recordButton
            Text("按一下開始講")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
        }
    }

    var titleRow: some View {
        HStack(spacing: Token.Space.s) {
            Text("錄音")
                .font(Token.Fonts.largeTitle)
                .foregroundStyle(Token.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Token.Space.s)
            if pendingCount > 0 {
                pendingCapsule
            }
        }
    }

    @ViewBuilder
    var recordButton: some View {
        let button = Button {
            isRecordingShown = true
        } label: {
            RecordButtonLabel()
        }
        .accessibilityLabel("開始錄音")

        // 光暈比鈕大一圈，當背景畫、不佔位置，托盤才不會被撐高。
        Group {
            // 減少動態時不縮放，用系統預設的按壓回饋（變淡）。
            if reduceMotion {
                button
            } else {
                button.buttonStyle(RecordButtonStyle())
            }
        }
        .background { RecordHalo() }
    }

    /// 06-首次體驗：金鑰橫幅在大標下面。整張可點，去設定頁。
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
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    /// 待轉錄（03-線框首頁 D；B1 改成大標右邊的淡金膠囊）：0 個時不出現，點了推入待轉錄清單。
    var pendingCapsule: some View {
        NavigationLink {
            PendingListView(onChange: reloadPending)
        } label: {
            AccentCapsule {
                Text("待轉錄 \(pendingCount) 個")
                    .fontWeight(.semibold)
                Image(systemName: "chevron.right")
                    .font(Token.Fonts.footnote.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Token.Shape.minTap)
            .contentShape(Rectangle())
        }
        // iOS 26 會替 NavigationLink 套一層灰色的系統按鈕底（2026-11-02 米真機截圖），膠囊自己有底，關掉系統那層。
        .buttonStyle(.plain)
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
