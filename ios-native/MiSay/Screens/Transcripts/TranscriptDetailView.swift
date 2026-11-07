import SwiftUI

/// 文字稿詳情（片 E1～E5）：正文是主角，口語稿可對照；底部工具列複製、重新潤飾、分享三顆平等。
/// 改字停下來 1 秒就存（E2）；刪除走「⋯」→ 動作表，復原在清單那邊（E3）；重新潤飾先問蓋掉或另存（E4）。
/// 2026-11-07 統一風格：正文放白卡片、工具列圖示在上字在下（`TranscriptToolbar`）、狀態條統一；
/// 改字、潤飾、複製那些動作搬到 `TranscriptDetailView+Editing.swift`，所以狀態不加 private。
struct TranscriptDetailView: View {
    /// 重新潤飾的兩種落點（詞彙表：「重新潤飾，蓋掉這篇」／「另存一篇」）。
    enum RepolishMode: Equatable {
        case overwrite
        case saveAsNew
    }

    @Environment(\.dismiss) var dismiss
    @State var transcript: Transcript
    @State var draftEdit: String
    @State var showsRawText = false
    @State var autosaveTask: Task<Void, Never>?
    @State var polishTask: Task<Void, Never>?
    @State var isPolishing = false
    @State var polishFailed = false
    @State var lastRepolishMode = RepolishMode.overwrite
    @State var isConfirmingRepolish = false
    @State var isConfirmingDelete = false
    @State var copyCount = 0
    @State var showsCopied = false
    @State var saveFailed = false
    @FocusState private var isEditing: Bool

    /// 刪除交給清單處理（它要顯示「已刪除・復原」）。
    let onDelete: (Transcript) -> Void

    /// 秒數照設計檔「草稿每次停止打字 1 秒就存」。
    static let autosaveDelaySeconds: Double = 1

    init(transcript: Transcript, onDelete: @escaping (Transcript) -> Void) {
        _transcript = State(initialValue: transcript)
        _draftEdit = State(initialValue: transcript.draftText ?? "")
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Token.Space.m) {
            meta
            if transcript.draftText != nil {
                sourcePicker
            }
            contentCard
        }
        .padding(.horizontal, Token.Space.l)
        .padding(.top, Token.Space.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.Colors.groupedBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .confirmationDialog(
            "會用現在的提示詞把口語稿重新整理一次。",
            isPresented: $isConfirmingRepolish,
            titleVisibility: .visible
        ) {
            Button("重新潤飾，蓋掉這篇") { repolish(.overwrite) }
            Button("另存一篇") { repolish(.saveAsNew) }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("刪掉這篇？", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("刪除這篇文字稿", role: .destructive) {
                flushAutosave()
                onDelete(transcript)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
        .sensoryFeedback(Token.Haptics.copied, trigger: copyCount)
        .onChange(of: draftEdit) { _, _ in scheduleAutosave() }
        .onDisappear { flushAutosave() }
    }

    /// 現在畫面上那份字：編輯中是編輯框的內容。
    var currentText: String {
        if transcript.draftText == nil || showsRawText {
            return transcript.rawText
        }
        return draftEdit
    }
}

/// 畫面的各塊：副標、分段控制、正文卡片、工具列。
private extension TranscriptDetailView {
    var meta: some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text(TranscriptListView.subtitle(for: transcript))
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
            // 片 F4：歷史看得出這篇用哪個模型潤飾。
            if let model = transcript.polishModel {
                Text("潤飾模型：\(model)")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Token.Space.xs)
    }

    /// 文字稿｜口語稿（線框詳情頁的分段控制）。
    var sourcePicker: some View {
        Picker("顯示", selection: $showsRawText) {
            Text("文字稿").tag(false)
            Text("口語稿").tag(true)
        }
        .pickerStyle(.segmented)
    }

    /// 正文放白卡片；只有口語稿時先講一句，再給「整理這篇」。
    var contentCard: some View {
        content
            .padding(Token.Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                Token.Colors.rowBackground,
                in: RoundedRectangle(cornerRadius: Token.Shape.radiusRow)
            )
    }

    @ViewBuilder
    var content: some View {
        if transcript.draftText == nil {
            VStack(alignment: .leading, spacing: Token.Space.m) {
                Text("這篇還沒整理成文字稿。")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                rawText
                if !isPolishing {
                    Button("整理這篇") { repolish(.overwrite) }
                        .buttonStyle(TextButtonStyle())
                }
            }
        } else if showsRawText {
            rawText
        } else {
            TextEditor(text: $draftEdit)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineSpacing(Token.Space.lineSpacing)
                .scrollContentBackground(.hidden)
                .focused($isEditing)
                // 潤飾中不給改：選「蓋掉這篇」時，這段時間打的字會被整篇換掉。
                .disabled(isPolishing)
                .accessibilityLabel("文字稿正文")
        }
    }

    var rawText: some View {
        ScrollView {
            Text(transcript.rawText)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .lineSpacing(Token.Space.lineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("刪除這篇文字稿", role: .destructive) { isConfirmingDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .tint(Token.Colors.link)
            .accessibilityLabel("更多")
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("完成") { isEditing = false }
                .tint(Token.Colors.link)
        }
    }

    /// 狀態條在工具列上方，一次只講一件事；工具列三顆平等，沒有主角。
    var bottomBar: some View {
        VStack(spacing: Token.Space.s) {
            TranscriptStatusStrip(kind: statusKind, onCancel: cancelPolish) {
                repolish(lastRepolishMode)
            }
            TranscriptToolbar(
                canCopy: !currentText.isEmpty,
                showsRepolish: !transcript.rawText.isEmpty,
                canRepolish: !isPolishing,
                shareItem: TranscriptTextFile(transcript: transcript, text: currentText),
                sharePreview: TranscriptListView.subtitle(for: transcript),
                onCopy: copy,
                onRepolish: { isConfirmingRepolish = true }
            )
        }
        .padding(.horizontal, Token.Space.l)
        .padding(.top, Token.Space.s)
        .background(Token.Colors.groupedBackground)
    }

    var statusKind: TranscriptStatusStrip.Kind {
        TranscriptStatusStrip.kind(
            isPolishing: isPolishing,
            polishFailed: polishFailed,
            hasDraft: transcript.draftText != nil,
            saveFailed: saveFailed,
            isEmpty: currentText.isEmpty,
            showsCopied: showsCopied
        )
    }
}
