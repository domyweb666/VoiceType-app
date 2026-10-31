import SwiftUI
import UniformTypeIdentifiers

/// 文字稿詳情（片 E1～E5）：正文是主角，口語稿可對照；底部工具列複製、重新潤飾、分享三顆平等。
/// 改字停下來 1 秒就存（E2）；刪除走「⋯」→ 動作表，復原在清單那邊（E3）；重新潤飾先問蓋掉或另存（E4）。
struct TranscriptDetailView: View {
    /// 重新潤飾的兩種落點（詞彙表：「重新潤飾，蓋掉這篇」／「另存一篇」）。
    enum RepolishMode: Equatable {
        case overwrite
        case saveAsNew
    }

    @Environment(\.dismiss) private var dismiss
    @State private var transcript: Transcript
    @State private var draftEdit: String
    @State private var showsRawText = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var polishTask: Task<Void, Never>?
    @State private var isPolishing = false
    @State private var polishFailed = false
    @State private var lastRepolishMode = RepolishMode.overwrite
    @State private var isConfirmingRepolish = false
    @State private var isConfirmingDelete = false
    @State private var copyCount = 0
    @State private var showsCopied = false
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
        ScrollView {
            VStack(alignment: .leading, spacing: Token.Space.m) {
                Text(TranscriptListView.subtitle(for: transcript))
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                if transcript.draftText != nil {
                    sourcePicker
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Token.Space.l)
        }
        .background(Token.Colors.groupedBackground)
        .navigationTitle("文字稿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { statusStrip }
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

    /// 文字稿｜口語稿（線框詳情頁的分段控制）。
    private var sourcePicker: some View {
        Picker("顯示", selection: $showsRawText) {
            Text("文字稿").tag(false)
            Text("口語稿").tag(true)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var content: some View {
        if transcript.draftText == nil {
            Text("這篇還沒整理成文字稿。")
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
            Text(transcript.rawText)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .textSelection(.enabled)
            if !isPolishing {
                Button("整理這篇") { repolish(.overwrite) }
                    .font(Token.Fonts.body)
                    .tint(Token.Colors.link)
            }
        } else if showsRawText {
            Text(transcript.rawText)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .textSelection(.enabled)
        } else {
            TextEditor(text: $draftEdit)
                .font(Token.Fonts.body)
                .foregroundStyle(Token.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isEditing)
                .frame(minHeight: Token.Shape.recordTap)
                .accessibilityLabel("文字稿正文")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("刪除", role: .destructive) { isConfirmingDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("更多")
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("完成") { isEditing = false }
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                copy()
            } label: {
                Label("複製", systemImage: "doc.on.doc")
            }
            .disabled(currentText.isEmpty)
            Spacer()
            if !transcript.rawText.isEmpty {
                Button {
                    isConfirmingRepolish = true
                } label: {
                    Label("重新潤飾", systemImage: "sparkles")
                }
                .disabled(isPolishing)
                Spacer()
            }
            ShareLink(item: TranscriptTextFile(transcript: transcript, text: currentText)) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            .disabled(currentText.isEmpty)
        }
    }

    /// 工具列上方那一行：潤飾中、潤飾失敗、沒有文字、已複製（首次體驗檔詳情狀態表）。
    @ViewBuilder
    private var statusStrip: some View {
        if isPolishing {
            HStack(spacing: Token.Space.s) {
                ProgressView()
                Text("重新潤飾中…舊的文字稿還在")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textSecondary)
                Spacer()
                Button("取消") { cancelPolish() }
                    .font(Token.Fonts.footnote)
                    .tint(Token.Colors.link)
            }
            .padding(.horizontal, Token.Space.l)
            .padding(.vertical, Token.Space.s)
            .background(Token.Colors.rowBackground)
        } else if polishFailed {
            HStack(alignment: .firstTextBaseline, spacing: Token.Space.s) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Token.Colors.danger)
                    .accessibilityHidden(true)
                Text("重新潤飾沒有成功，文字稿沒有被改動。")
                    .font(Token.Fonts.footnote)
                    .foregroundStyle(Token.Colors.textPrimary)
                Spacer()
                Button("再試一次") { repolish(lastRepolishMode) }
                    .font(Token.Fonts.footnote)
                    .tint(Token.Colors.link)
            }
            .padding(.horizontal, Token.Space.l)
            .padding(.vertical, Token.Space.s)
            .background(Token.Colors.rowBackground)
        } else if currentText.isEmpty {
            Text("沒有文字可以複製")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
                .padding(.vertical, Token.Space.s)
        } else if showsCopied {
            Text("已複製")
                .font(Token.Fonts.footnote)
                .foregroundStyle(Token.Colors.textSecondary)
                .padding(.vertical, Token.Space.s)
        }
    }

    /// 現在畫面上那份字：編輯中是編輯框的內容。
    private var currentText: String {
        if transcript.draftText == nil || showsRawText {
            return transcript.rawText
        }
        return draftEdit
    }

    private func copy() {
        UIPasteboard.general.string = currentText
        copyCount += 1
        showsCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            showsCopied = false
        }
    }

    // MARK: - E2 改字自動存

    private func scheduleAutosave() {
        guard transcript.draftText != nil, draftEdit != transcript.draftText else {
            return
        }
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.autosaveDelaySeconds))
            guard !Task.isCancelled else {
                return
            }
            flushAutosave()
        }
    }

    /// 存不進去只能大聲：用潤飾失敗那一行的位置顯示。畫面上的字不會丟（還在編輯框裡）。
    private func flushAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard transcript.draftText != nil, draftEdit != transcript.draftText else {
            return
        }
        var updated = transcript
        updated.draftText = draftEdit
        updated.updatedAt = Date()
        do {
            try TranscriptStore().save(updated)
            transcript = updated
        } catch {
            polishFailed = false
            saveFailed = true
        }
    }

    @State private var saveFailed = false

    // MARK: - E4 重新潤飾

    private func repolish(_ mode: RepolishMode) {
        flushAutosave()
        lastRepolishMode = mode
        polishFailed = false
        isPolishing = true
        let settings = AppSettings.shared
        let source = transcript
        polishTask = Task { @MainActor in
            do {
                let draft = try await Polisher().polish(
                    rawText: source.rawText,
                    model: settings.polishModel,
                    systemPrompt: settings.effectivePolishPrompt,
                    vocabulary: settings.vocabulary
                )
                try applyRepolish(draft, mode: mode, model: settings.polishModel)
            } catch is CancellationError {
                // 使用者自己按取消，不跳訊息（詞彙表語氣規則）。
            } catch OpenAIClient.Failure.transport(.cancelled) {
                // 同上：取消在連線層的樣子。
            } catch {
                polishFailed = true
            }
            isPolishing = false
        }
    }

    private func applyRepolish(_ draft: String, mode: RepolishMode, model: String) throws {
        let store = TranscriptStore()
        switch mode {
        case .overwrite:
            var updated = transcript
            updated.draftText = draft
            updated.polishModel = model
            updated.updatedAt = Date()
            try store.save(updated)
            transcript = updated
            draftEdit = draft
        case .saveAsNew:
            let copy = Transcript(
                durationSeconds: transcript.durationSeconds,
                rawText: transcript.rawText,
                draftText: draft,
                polishModel: model
            )
            try store.save(copy)
            dismiss()
        }
    }

    private func cancelPolish() {
        polishTask?.cancel()
        polishTask = nil
        isPolishing = false
    }
}

/// 分享用的純文字檔（E5）：系統分享表單對「檔案」才會出現「儲存到檔案」。
struct TranscriptTextFile: Transferable {
    let transcript: Transcript
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            let name = file.transcript.createdAt.formatted(.iso8601.year().month().day()) + ".txt"
            let url = FileManager.default.temporaryDirectory.appending(path: name)
            try file.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
