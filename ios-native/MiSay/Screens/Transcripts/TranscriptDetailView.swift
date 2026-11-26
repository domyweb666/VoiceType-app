import SwiftUI

/// 文字稿詳情（片 E1～E5）。2026-11-08 米：米說是讓人錄很長、再簡單修飾的，這頁改成備忘錄式編輯器。
/// 整頁白紙就是正文；頂上返回、匯出、複製、「⋯」，打字時右上多一顆玉米黃的勾（完成）。
/// 口語稿與錄音收進「⋯ → 錄音與原稿」，從下面升起一張唯讀的頁。改字停下來 1 秒就存（E2）；刪除走「⋯」（E3）。
/// 重新潤飾拿掉了（會把改好的字整篇蓋掉）；只剩還沒有文字稿的那篇有「整理這篇」。
/// 改字、整理、複製那些動作在 `TranscriptDetailView+Editing.swift`，所以狀態不加 private。
/// 2026-11-24 Y4：正文上面有標題；錄音面板直接升在這頁上。
struct TranscriptDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(TranscriptionQueue.self) var queue
    @Environment(Recorder.self) var recorder
    @State var transcript: Transcript
    @State var draftEdit: String
    /// Y6：錄音與原稿那張頁（口語稿、AI 改了什麼、聽原音、重新轉錄）。
    @State var showsSource = false
    @State var autosaveTask: Task<Void, Never>?
    @State var polishTask: Task<Void, Never>?
    @State var isPolishing = false
    @State var polishFailed = false
    @State var isConfirmingDelete = false
    /// Y1：匯出那張頁。
    @State var showsExport = false
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
    /// 「這趟講了幾件事」那張頁，與這次打開分到的結果（`+Split`）。
    @State var showsSplit = false
    @State var split = SplitSheet.Session()
    /// W6：編這篇標籤的那張頁。
    @State var showsTags = false
    /// 打開標籤頁那一下讀的舊標籤；放在頁的內容裡算的話，頁每重畫一次就讀一次全部文字稿（性能檢查 H2）。
    @State var knownTags: [String] = []
    /// 底下那行一下就收的一句話。
    @State var note: String?
    @State var copyCount = 0
    @State var showsCopied = false
    @State var saveFailed = false
    /// 2026-11-15 寫長文：大綱與尋找那張頁、要跳到第幾個字。
    @State var showsOutline = false
    @State var jumpTarget: Range<Int>?
    /// Y6：打開時是一篇空白新文稿，離開時還是空的就不留；這頁自己收掉了沒（`+Leaving`）。
    @State var openedBlank: Bool
    @State var wasDiscarded = false
    /// 打開這頁時是第幾次刪光之後（`TranscriptStore+Erase`）：中間刪過全部資料，這頁的字就不存回去。
    @State var openedEraseGeneration: Int
    /// 版本紀錄那張頁；下次該留版的時間（nil 是這次打開還沒留過）。
    @State var showsVersions = false
    @State var versionDueAt: Date?
    /// 用哪一種編輯框：打開這頁時讀一次，開著這頁不中途換。
    @State var usesPlainEditor = AppSettings.shared.usesPlainEditor
    /// 鍵盤是不是升著，一種編輯框一份：系統的看焦點，新的自己回報。要讀要寫都走 `isEditing`。
    @State var isPlainEditing = false
    @State var editorHandle = PlainTextHandle()
    /// Y4 標題（`+Title`）、在這頁錄音（`+RecordHere`）。
    @State var titleEdit: String
    @State var titleTask: Task<Void, Never>?
    @State var titleSaveFailed = false
    @FocusState var isTitleFocused: Bool
    @State var showsRecorder = false
    @State var recordInsertion: InsertionPoint?
    @State var editorToken = UUID()
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
        _openedBlank = State(initialValue: transcript.isBlankDraft)
        _openedEraseGeneration = State(initialValue: TranscriptStore.eraseGeneration)
        _titleEdit = State(initialValue: transcript.title ?? "")
        self.openedFrom = openedFrom
        self.onDelete = onDelete
        self.onLeave = onLeave
    }

    var body: some View {
        withSplit(withRecording(page))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Token.Colors.rowBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { bottomLine }
            .sheet(isPresented: $showsSource) { sourceSheet }
            .sheet(isPresented: $showsRewrites, onDismiss: openPendingRelated) { rewritesSheet }
            .sheet(isPresented: $derived.showsThreadsParts) { threadsPartsSheet }
            .navigationDestination(isPresented: $derived.showsOpened) { relatedPage }
            .sheet(isPresented: $showsReview) { reviewSheet }
            .sheet(isPresented: $showsTags) { tagsSheet }
            .sheet(isPresented: $showsOutline) { outlineSheet }
            .sheet(isPresented: $showsVersions) { versionsSheet }
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
            .sensoryFeedback(Token.Haptics.copied, trigger: copyCount)
            .onChange(of: draftEdit) { _, _ in scheduleAutosave() }
            .onAppear(perform: pageAppeared)
            .onDisappear {
                // 離開這頁就停：再打開這篇是另一份畫面，改寫完存回來會跟它互相蓋。
                cancelRewrite()
                cancelReview()
                cancelSplit()
                leaveEditor()
                discardIfBlank()
                // 這次改對的詞加進自訂詞彙（開關關著就不跑）。
                // 只看這一篇，不為了一篇把全部文字稿讀一次（性能檢查 H2）。
                CorrectedWordsRunner.start(only: transcript.id)
                onLeave()
            }
    }

    /// 複製、匯出用的那份：有文字稿就是編輯框裡的字，沒有就是口語稿。
    var currentText: String {
        transcript.draftText == nil ? transcript.rawText : draftEdit
    }
}

/// 畫面的各塊：正文、頂上一排、底下一行。錄音與原稿那張頁在 `SourceSheet`。
private extension TranscriptDetailView {
    var page: some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            titleField
            if transcript.draftText == nil {
                unpolishedPage
            } else {
                editor
            }
        }
    }

    /// 日期放在頂上中間，不佔正文的地方（備忘錄也是這樣）。打字時換成字數（寫長文要看進度），點了設目標。
    @ViewBuilder
    var dateTitle: some View {
        if isTyping {
            progressMenu
        } else {
            Text(TranscriptListView.subtitle(for: transcript))
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) { dateTitle }
        if isTyping {
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
            isTitleFocused = false
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
        } else if !isTyping, !currentText.isEmpty {
            progressMenu
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, Token.Space.screen)
        }
    }

    var statusKind: TranscriptStatusStrip.Kind {
        TranscriptStatusStrip.kind(
            isPolishing: isPolishing,
            polishFailed: polishFailed,
            saveFailed: saveFailed,
            titleSaveFailed: titleSaveFailed,
            isEmpty: currentText.isEmpty && !transcript.isWritten && !transcript.isDerived,
            showsCopied: showsCopied,
            note: note,
            possiblyMissing: transcript.possiblyMissingSegments ?? []
        )
    }
}
