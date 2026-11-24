import SwiftUI

/// 文字稿詳情（片 E1～E5）。2026-11-08 米：米說是讓人錄很長、再簡單修飾的，這頁改成備忘錄式編輯器。
/// 整頁白紙就是正文；頂上返回、匯出、複製、「⋯」，打字時右上多一顆玉米黃的勾（完成）。
/// 口語稿收進「⋯ → 看口語稿」，從下面升起一張唯讀的頁。改字停下來 1 秒就存（E2）；刪除走「⋯」（E3）。
/// 重新潤飾拿掉了（會把改好的字整篇蓋掉）；只剩還沒有文字稿的那篇有「整理這篇」。
/// 改字、整理、複製那些動作在 `TranscriptDetailView+Editing.swift`，所以狀態不加 private。
struct TranscriptDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(TranscriptionQueue.self) var queue
    @State var transcript: Transcript
    @State var draftEdit: String
    @State var showsRawText = false
    /// W3：口語稿那張頁一打開就停在「AI 改了什麼」。
    @State var rawSheetStartsWithDiff = false
    @State var autosaveTask: Task<Void, Never>?
    @State var polishTask: Task<Void, Never>?
    @State var isPolishing = false
    @State var polishFailed = false
    @State var isConfirmingDelete = false
    @State var isConfirmingRetranscribe = false
    /// Y1：匯出那張頁。
    @State var showsExport = false
    /// K5：聽原音與重點那一頁。
    @State var showsOriginalAudio = false
    /// W1：改寫成其他格式那張頁、正在改寫哪一種、改寫沒成功那句話。
    @State var showsRewrites = false
    @State var rewritingKind: RewriteKind?
    @State var rewriteTask: Task<Void, Never>?
    @State var rewriteFailure: String?
    /// Y5：改寫好的那幾篇、要開哪一篇、逐篇複製那張頁。
    @State var derived = DerivedPages()
    /// 請 AI 看整篇那張頁，與這次打開問到的意見（離開這頁就不留）。
    @State var showsReview = false
    @State var review = ReviewSheet.Session()
    /// W6：編這篇標籤的那張頁。
    @State var showsTags = false
    /// 底下那行一下就收的一句話。
    @State var note: String?
    @State var copyCount = 0
    @State var showsCopied = false
    @State var saveFailed = false
    /// 2026-11-15 寫長文：大綱與尋找那張頁、要跳到第幾個字、是不是要去錄音（空白新文稿不刪）。
    @State var showsOutline = false
    @State var jumpTarget: Range<Int>?
    @State var isLeavingToRecord = false
    /// 版本紀錄那張頁；下次該留版的時間（nil 是這次打開還沒留過）。
    @State var showsVersions = false
    @State var versionDueAt: Date?
    /// 2026-11-15：新的編輯框（試用）。打開這頁時讀一次，開著這頁不中途換。
    @State var usesPlainEditor = AppSettings.shared.usesPlainEditor
    /// 鍵盤是不是升著，一種編輯框一份：系統的看焦點，新的自己回報。要讀要寫都走 `isEditing`。
    @State var isPlainEditing = false
    @FocusState var isSystemEditorFocused: Bool

    /// Y5：從哪一篇點進來的（改寫稿與原篇互相開）；清單開的是 nil。
    let openedFrom: UUID?
    /// 刪除交給清單處理（它要顯示「已刪除・復原」）。
    let onDelete: (Transcript) -> Void
    /// 離開這頁、該存該丟的都做完之後叫一次。清單靠它重讀：它自己回到畫面時讀的那次比這裡早，
    /// 空白新文稿還沒丟、最後幾個字還沒存（2026-11-16 模擬器上看到空白那篇留在清單）。
    let onLeave: () -> Void

    /// 秒數照設計檔「草稿每次停止打字 1 秒就存」。
    static let autosaveDelaySeconds: Double = 1

    /// 「潤飾：保留原聲・gpt-5.4-mini」；以前的篇沒記潤飾方式，照舊「潤飾模型：x」。
    static func polishNote(model: String, style: String?) -> String {
        guard let title = PolishStyle.title(forStored: style) else {
            return "潤飾模型：\(model)"
        }
        return "潤飾：\(title)・\(model)"
    }

    init(
        transcript: Transcript,
        openedFrom: UUID? = nil,
        onDelete: @escaping (Transcript) -> Void,
        onLeave: @escaping () -> Void = {}
    ) {
        _transcript = State(initialValue: transcript)
        _draftEdit = State(initialValue: transcript.draftText ?? "")
        self.openedFrom = openedFrom
        self.onDelete = onDelete
        self.onLeave = onLeave
    }

    var body: some View {
        page
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Token.Colors.rowBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { bottomLine }
            .sheet(isPresented: $showsRawText) {
                RawTextSheet(transcript: transcript, startsWithDiff: rawSheetStartsWithDiff)
            }
            .sheet(isPresented: $showsRewrites, onDismiss: openPendingRelated) { rewritesSheet }
            .sheet(isPresented: $derived.showsThreadsParts) { threadsPartsSheet }
            .navigationDestination(isPresented: $derived.showsOpened) { relatedPage }
            .sheet(isPresented: $showsReview) { reviewSheet }
            .sheet(isPresented: $showsTags) { tagsSheet }
            .sheet(isPresented: $showsOutline) { outlineSheet }
            .sheet(isPresented: $showsVersions) { versionsSheet }
            .sheet(isPresented: $showsOriginalAudio) {
                // 接著錄過的篇，留著的錄音只對得上第一段，位置會估錯，不給播。
                OriginalAudioSheet(
                    transcript: transcript,
                    audioURL: transcript.combinedAt != nil
                        ? nil
                        : RetainedRecordings().existingURL(for: transcript.id)
                )
            }
            .sheet(isPresented: $showsExport) { exportSheet }
            .confirmationDialog(
                "刪掉這篇？",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("刪除這篇文字稿", role: .destructive) {
                    flushAutosave()
                    onDelete(transcript)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog(
                "用錄音重新轉一次？",
                isPresented: $isConfirmingRetranscribe,
                titleVisibility: .visible
            ) {
                Button("重新轉錄", action: retranscribe)
                Button("取消", role: .cancel) {}
            } message: {
                Text("口語稿和文字稿都會換成新的，你改過的字會不見。")
            }
            .sensoryFeedback(Token.Haptics.copied, trigger: copyCount)
            .onChange(of: draftEdit) { _, _ in scheduleAutosave() }
            // K3：接著錄、從錄音重新轉錄都可能在這頁不在畫面上時改了這篇；回來先讀最新的，
            // 不然改字自動存會拿舊的那份蓋掉接上去的字。
            .onAppear {
                reloadFromStore()
                queue.openForEditing.insert(transcript.id)
                focusIfBlank()
                if queue.insertionsMovedToEnd.remove(transcript.id) != nil {
                    showNote("剛才錄的那段找不到原本的位置（那附近改過了），接在最後面。")
                }
            }
            .onDisappear { queue.openForEditing.remove(transcript.id) }
            .onDisappear {
                // 離開這頁就停：再打開這篇是另一份畫面，改寫完存回來會跟它互相蓋。
                cancelRewrite()
                cancelReview()
                flushAutosave()
                discardIfBlank()
                // 改完離開就學這次改了什麼（自動詞彙、從修改學習；兩個都關著就不跑）。
                EditLearningRunner.start()
                onLeave()
            }
    }

    /// 複製、匯出用的那份：有文字稿就是編輯框裡的字，沒有就是口語稿。
    var currentText: String {
        transcript.draftText == nil ? transcript.rawText : draftEdit
    }
}

/// 畫面的各塊：正文、頂上一排、底下一行。口語稿那張頁在 `RawTextSheet`。
private extension TranscriptDetailView {
    @ViewBuilder
    var page: some View {
        if transcript.draftText == nil {
            unpolishedPage
        } else {
            // iOS 18 起鍵盤上方多一排：格式（W5）、在這裡接著錄、選一段叫 AI 改（W4），在 `DraftEditor`；
            // iOS 17 拿不到選取範圍，只能打字。
            Group {
                if usesPlainEditor {
                    PlainDraftEditor(
                        text: $draftEdit,
                        canRecordHere: !isPolishing,
                        onRecordHere: insertRecording(at:),
                        isEditing: $isPlainEditing,
                        jump: $jumpTarget
                    )
                } else if #available(iOS 18, *) {
                    DraftEditor(
                        text: $draftEdit,
                        canRecordHere: !isPolishing,
                        onRecordHere: insertRecording(at:),
                        isEditing: isEditing,
                        jump: $jumpTarget
                    )
                } else {
                    TextEditor(text: $draftEdit)
                }
            }
            .font(Token.Fonts.body)
            .foregroundStyle(Token.Colors.textPrimary)
            .lineSpacing(Token.Space.lineSpacing)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            // 最後一行底下留白（米 11/17：打到最下面，字貼著鍵盤那一排）。試用的編輯框在 `PlainTextView` 自己留。
            .contentMargins(.bottom, Token.Space.editorBottom, for: .scrollContent)
            .focused($isSystemEditorFocused)
            // TextEditor 自己裡面還有一點內距，外面補到跟清單卡片的字差不多齊。
            // 上緣留一點白（米 11/09：第一行貼著頂上那排太近）。
            .padding(.horizontal, Token.Space.m)
            .padding(.top, Token.Space.m)
            .accessibilityLabel("文字稿正文")
        }
    }

    /// 日期放在標題位置，小小的兩行，不佔正文的地方（備忘錄也是這樣）。打字時換成字數（寫長文要看進度）。
    var dateTitle: some View {
        Text(isEditing ? progressText : TranscriptListView.subtitle(for: transcript))
            .font(Token.Fonts.footnote)
            .foregroundStyle(Token.Colors.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) { dateTitle }
        if isEditing {
            ToolbarItemGroup(placement: .topBarTrailing) {
                outlineButton
                doneButton
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                exportButton
                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("複製全文")
                moreMenu
            }
        }
    }

    /// 這頁唯一的主要按鈕（domy：金棕底白字）：打字時才出現，按了收鍵盤（字早就自動存了）。
    var doneButton: some View {
        Button {
            isEditing = false
        } label: {
            Image(systemName: "checkmark")
                .fontWeight(.semibold)
                .foregroundStyle(Token.Colors.onAccent)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(Token.Colors.accent)
        .accessibilityLabel("完成")
    }

    /// 底下一行：有狀態就講狀態（一次一件），沒有就在不打字時顯示字數。
    @ViewBuilder
    var bottomLine: some View {
        if statusKind != .hidden {
            TranscriptStatusStrip(kind: statusKind, onCancel: cancelPolish, onRetry: polishThis)
                .padding(.horizontal, Token.Space.screen)
                .padding(.bottom, Token.Space.s)
        } else if !isEditing, !currentText.isEmpty {
            Text(progressText)
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, Token.Space.screen)
                .padding(.vertical, Token.Space.s)
        }
    }

    var statusKind: TranscriptStatusStrip.Kind {
        TranscriptStatusStrip.kind(
            isPolishing: isPolishing,
            polishFailed: polishFailed,
            saveFailed: saveFailed,
            isEmpty: currentText.isEmpty && !transcript.isWritten,
            showsCopied: showsCopied,
            note: note,
            possiblyMissing: transcript.possiblyMissingSegments ?? []
        )
    }
}
