import SwiftUI

/// 2026-11-15 米：光用手機就要能在編輯區打出五千字以上的長文。這個檔放寫長文用的那幾樣：
/// 新文稿打開就能打；大綱與尋找；字數目標。還沒整理的那一頁也搬來這裡（主檔快到 300 行）。
extension TranscriptDetailView {
    static let goalOptions = [1000, 2000, 3000, 5000, 8000, 10000]
    /// 推頁的動畫跑完再升鍵盤，太早叫會沒反應。
    static let focusDelayMilliseconds = 500
    /// 大綱那張頁收下去之後才放得了游標。
    static let jumpDelayMilliseconds = 150

    /// 「1,234 字」；有設目標是「1,234／5,000 字」。
    static func progress(count: Int, goal: Int?) -> String {
        guard let goal else {
            return "\(count.formatted()) 字"
        }
        return "\(count.formatted())／\(goal.formatted()) 字"
    }

    static func goalMenuTitle(_ goal: Int?) -> String {
        goal.map { "字數目標：\($0.formatted()) 字" } ?? "設字數目標"
    }

    /// 鍵盤是不是升著。兩種編輯框各記各的，其他地方只認這一個。
    var isEditing: Bool {
        get { usesPlainEditor ? isPlainEditing : isSystemEditorFocused }
        nonmutating set {
            if usesPlainEditor {
                isPlainEditing = newValue
            } else {
                isSystemEditorFocused = newValue
            }
        }
    }

    var progressText: String {
        Self.progress(
            count: DictationStats.countCharacters(currentText),
            goal: transcript.goalCharacters
        )
    }

    /// 鍵盤上方多一排：格式（`FormatBar`）、在這裡接著錄、選一段叫 AI 改（W4）。
    /// 用舊的編輯框而且是 iOS 17 的，拿不到選取範圍，只能打字。
    var editor: some View {
        Group {
            if usesPlainEditor {
                PlainDraftEditor(
                    text: $draftEdit,
                    canRecordHere: !isPolishing,
                    onRecordHere: insertRecording(at:),
                    isEditing: $isPlainEditing,
                    jump: $jumpTarget,
                    handle: editorHandle
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
                    .accessibilityLabel("文字稿正文")
            }
        }
        .font(Token.Fonts.body)
        .foregroundStyle(Token.Colors.textPrimary)
        .lineSpacing(Token.Space.lineSpacing)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        // 最後一行底下留白（米 11/17：打到最下面，字貼著鍵盤那一排）。`PlainTextView` 自己留。
        .contentMargins(.bottom, Token.Space.editorBottom, for: .scrollContent)
        .focused($isSystemEditorFocused)
        // TextEditor 自己裡面還有一點內距，外面補到跟清單卡片的字差不多齊。
        .padding(.horizontal, Token.Space.m)
    }

    /// 還沒整理成文字稿：先講一句，口語稿照樣看得到、複製得到，再給「整理這篇」。
    var unpolishedPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Token.Space.m) {
                Text("這篇還沒整理成文字稿。")
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textSecondary)
                Text(transcript.rawText)
                    .font(Token.Fonts.body)
                    .foregroundStyle(Token.Colors.textPrimary)
                    .lineSpacing(Token.Space.lineSpacing)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !isPolishing {
                    Button("整理這篇", action: polishThis)
                        .buttonStyle(TextButtonStyle())
                }
            }
            .padding(.horizontal, Token.Space.screen)
            .padding(.top, Token.Space.s)
        }
    }

    /// 新文稿一打開就升鍵盤，不用再點一下。
    func focusIfBlank() {
        guard transcript.isBlankDraft else {
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.focusDelayMilliseconds))
            isEditing = true
        }
    }

    /// 打字時頂上那顆、「⋯」裡那一列都開同一張頁。
    var outlineButton: some View {
        Button {
            showsOutline = true
        } label: {
            Image(systemName: "list.bullet.indent")
        }
        .accessibilityLabel("大綱與尋找")
    }

    var outlineSheet: some View {
        OutlineSheet(
            text: draftEdit,
            onJump: jump(to:),
            onReplaceAll: replaceAll(_:with:),
            onReorder: reorder(to:)
        )
    }

    /// 先升鍵盤再放游標：編輯框還沒拿到焦點時放的游標會被蓋掉。
    func jump(to range: Range<Int>) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.focusDelayMilliseconds))
            isEditing = true
            try? await Task.sleep(for: .milliseconds(Self.jumpDelayMilliseconds))
            jumpTarget = range
        }
    }

    /// 鍵盤升著：在打正文或標題。
    var isTyping: Bool {
        isEditing || isTitleFocused
    }

    /// 字數，點了設目標（2026-11-24 從「⋯」搬來）。還沒有文字稿的篇只看字數。
    @ViewBuilder
    var progressMenu: some View {
        let label = Text(progressText)
            .font(Token.Fonts.footnote)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        if transcript.draftText == nil {
            label.foregroundStyle(Token.Colors.textSecondary)
        } else {
            Menu {
                Picker("字數目標", selection: goalBinding) {
                    Text("不設").tag(Int?.none)
                    ForEach(Self.goalOptions, id: \.self) { goal in
                        Text("\(goal.formatted()) 字").tag(Int?.some(goal))
                    }
                }
            } label: {
                label.foregroundStyle(Token.Colors.link)
                    .frame(minHeight: Token.Shape.minTap)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(progressText + "，" + Self.goalMenuTitle(transcript.goalCharacters))
        }
    }

    /// 「⋯」裡寫長文用的兩列：大綱與尋找、版本紀錄。只有已經有文字稿的篇有。
    @ViewBuilder
    var writingMenuItems: some View {
        if transcript.draftText != nil {
            Button {
                showsOutline = true
            } label: {
                Label("大綱與尋找", systemImage: "list.bullet.indent")
            }
            .disabled(currentText.isEmpty)
            Button {
                showsVersions = true
            } label: {
                Label(
                    Self.versionMenuTitle(count: transcript.versions?.count ?? 0),
                    systemImage: "clock.arrow.circlepath"
                )
            }
        }
    }

    private var goalBinding: Binding<Int?> {
        Binding(
            get: { transcript.goalCharacters },
            set: { goal in
                do {
                    try updateStored {
                        $0.goalCharacters = goal
                        $0.updatedAt = Date()
                    }
                } catch {
                    showNote("字數目標沒存進去，再試一次。")
                }
            }
        )
    }
}
