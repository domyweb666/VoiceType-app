import SwiftUI

/// 文字稿詳情（片 E1～E5）。2026-11-08 米：米說是讓人錄很長、再簡單修飾的，這頁改成備忘錄式編輯器。
/// 整頁白紙就是正文；頂上返回、分享、複製、「⋯」，打字時右上多一顆玉米黃的勾（完成）。
/// 口語稿收進「⋯ → 看口語稿」，從下面升起一張唯讀的頁。改字停下來 1 秒就存（E2）；刪除走「⋯」（E3）。
/// 重新潤飾拿掉了（會把改好的字整篇蓋掉）；只剩還沒有文字稿的那篇有「整理這篇」。
/// 改字、整理、複製那些動作在 `TranscriptDetailView+Editing.swift`，所以狀態不加 private。
struct TranscriptDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(TranscriptionQueue.self) var queue
    @State var transcript: Transcript
    @State var draftEdit: String
    @State var showsRawText = false
    @State var autosaveTask: Task<Void, Never>?
    @State var polishTask: Task<Void, Never>?
    @State var isPolishing = false
    @State var polishFailed = false
    @State var isConfirmingDelete = false
    @State var isConfirmingRetranscribe = false
    /// K2：選 Markdown 要存到哪個資料夾。
    @State var isPickingMarkdownFolder = false
    /// K5：聽原音與重點那一頁。
    @State var showsOriginalAudio = false
    /// 底下那行一下就收的一句話（K2 存好了、存不進去）。
    @State var note: String?
    @State var copyCount = 0
    @State var showsCopied = false
    @State var saveFailed = false
    @FocusState var isEditing: Bool

    /// 刪除交給清單處理（它要顯示「已刪除・復原」）。
    let onDelete: (Transcript) -> Void

    /// 秒數照設計檔「草稿每次停止打字 1 秒就存」。
    static let autosaveDelaySeconds: Double = 1

    /// 「潤飾：保留原聲・gpt-5.4-mini」；以前的篇沒記潤飾方式，照舊「潤飾模型：x」。
    static func polishNote(model: String, style: String?) -> String {
        guard let title = PolishStyle.title(forStored: style) else {
            return "潤飾模型：\(model)"
        }
        return "潤飾：\(title)・\(model)"
    }

    /// 「1,234 字」：空白和換行不算。
    static func characterCount(_ text: String) -> String {
        "\(DictationStats.countCharacters(text).formatted()) 字"
    }

    init(transcript: Transcript, onDelete: @escaping (Transcript) -> Void) {
        _transcript = State(initialValue: transcript)
        _draftEdit = State(initialValue: transcript.draftText ?? "")
        self.onDelete = onDelete
    }

    var body: some View {
        page
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Token.Colors.rowBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { bottomLine }
            .sheet(isPresented: $showsRawText) { rawTextSheet }
            .sheet(isPresented: $showsOriginalAudio) {
                // 接著錄過的篇，留著的錄音只對得上第一段，位置會估錯，不給播。
                OriginalAudioSheet(
                    transcript: transcript,
                    audioURL: transcript.combinedAt != nil
                        ? nil
                        : RetainedRecordings().existingURL(for: transcript.id)
                )
            }
            .fileImporter(
                isPresented: $isPickingMarkdownFolder,
                allowedContentTypes: [.folder],
                onCompletion: pickedMarkdownFolder
            )
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
            }
            .onDisappear { queue.openForEditing.remove(transcript.id) }
            .onDisappear {
                flushAutosave()
                // 改完離開就學這次改了什麼（自動詞彙、從修改學習；兩個都關著就不跑）。
                EditLearningRunner.start()
            }
    }

    /// 複製、分享用的那份：有文字稿就是編輯框裡的字，沒有就是口語稿。
    var currentText: String {
        transcript.draftText == nil ? transcript.rawText : draftEdit
    }
}

/// 畫面的各塊：正文、頂上一排、底下一行、口語稿那張頁。
private extension TranscriptDetailView {
    @ViewBuilder
    var page: some View {
        if transcript.draftText == nil {
            unpolishedPage
        } else {
            TextEditor(text: $draftEdit)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineSpacing(Token.Space.lineSpacing)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .focused($isEditing)
                // TextEditor 自己裡面還有一點內距，外面補到跟清單卡片的字差不多齊。
                .padding(.horizontal, Token.Space.m)
                .accessibilityLabel("文字稿正文")
        }
    }

    /// 還沒整理成文字稿：先講一句，口語稿照樣看得到、複製得到，再給「整理這篇」。
    var unpolishedPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Token.Space.m) {
                Text("這篇還沒整理成文字稿。")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                rawText
                if !isPolishing {
                    Button("整理這篇", action: polishThis)
                        .buttonStyle(TextButtonStyle())
                }
            }
            .padding(.horizontal, Token.Space.l)
            .padding(.top, Token.Space.s)
        }
    }

    var rawText: some View {
        Text(transcript.rawText)
            .font(Token.Fonts.body)
            .foregroundStyle(Token.Colors.textPrimary)
            .lineSpacing(Token.Space.lineSpacing)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 日期放在標題位置，小小的兩行，不佔正文的地方（備忘錄也是這樣）。
    var dateTitle: some View {
        Text(TranscriptListView.subtitle(for: transcript))
            .font(Token.Fonts.footnote)
            .foregroundStyle(Token.Colors.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) { dateTitle }
        if isEditing {
            ToolbarItem(placement: .topBarTrailing) { doneButton }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(
                    item: TranscriptTextFile(transcript: transcript, text: currentText),
                    preview: SharePreview(TranscriptListView.subtitle(for: transcript))
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(currentText.isEmpty)
                .accessibilityLabel("分享")
                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("複製全文")
                moreMenu
            }
        }
    }

    /// 這頁唯一的玉米黃：打字時才出現，按了收鍵盤（字早就自動存了）。
    var doneButton: some View {
        Button {
            isEditing = false
        } label: {
            Image(systemName: "checkmark")
                .fontWeight(.semibold)
                .foregroundStyle(Token.Colors.actionInk)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(Token.Colors.actionFill)
        .accessibilityLabel("完成")
    }

    /// 底下一行：有狀態就講狀態（一次一件），沒有就在不打字時顯示字數。
    @ViewBuilder
    var bottomLine: some View {
        if statusKind != .hidden {
            TranscriptStatusStrip(kind: statusKind, onCancel: cancelPolish, onRetry: polishThis)
                .padding(.horizontal, Token.Space.l)
                .padding(.bottom, Token.Space.s)
        } else if !isEditing, !currentText.isEmpty {
            Text(Self.characterCount(currentText))
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, Token.Space.l)
                .padding(.vertical, Token.Space.s)
        }
    }

    /// 口語稿：唯讀、可以選字複製，看完拉下去。
    var rawTextSheet: some View {
        NavigationStack {
            ScrollView {
                rawText
                    .padding(Token.Space.l)
            }
            .background(Token.Colors.rowBackground)
            .navigationTitle("口語稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showsRawText = false }
                        .tint(Token.Colors.link)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
    }

    var statusKind: TranscriptStatusStrip.Kind {
        TranscriptStatusStrip.kind(
            isPolishing: isPolishing,
            polishFailed: polishFailed,
            saveFailed: saveFailed,
            isEmpty: currentText.isEmpty,
            showsCopied: showsCopied,
            note: note,
            possiblyMissing: transcript.possiblyMissingSegments ?? []
        )
    }
}
