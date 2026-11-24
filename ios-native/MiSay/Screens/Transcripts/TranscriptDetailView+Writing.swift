import SwiftUI

/// 2026-11-15 米：光用手機就要能在編輯區打出五千字以上的長文。這個檔放寫長文用的那幾樣：
/// 新文稿打開就能打、沒寫就不留；大綱與尋找；字數目標。還沒整理的那一頁也搬來這裡（主檔快到 300 行）。
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
        goal.map { "字數目標：\($0.formatted()) 字" } ?? "字數目標…"
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

    /// 新文稿一個字都沒寫就離開：不留一篇空白的在清單。按了「在這裡接著錄」是去錄音，不算。
    /// 有改寫稿的原篇也不丟：跟以前改寫稿掛在底下時一樣。
    func discardIfBlank() {
        guard derived.transcripts.isEmpty, !isLeavingToRecord, draftEdit == transcript.draftText,
              transcript.isBlankDraft
        else {
            return
        }
        do {
            try TranscriptStore().delete(id: transcript.id)
        } catch {
            DiagnosticLog.shared.record("空白新文稿沒刪掉：\(type(of: error))")
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

    /// 「⋯」裡寫長文用的三列：大綱與尋找、字數目標、版本紀錄。只有已經有文字稿的篇有。
    @ViewBuilder
    var writingMenuItems: some View {
        if transcript.draftText != nil {
            Button {
                showsOutline = true
            } label: {
                Label("大綱與尋找", systemImage: "list.bullet.indent")
            }
            .disabled(currentText.isEmpty)
            Menu {
                Picker("字數目標", selection: goalBinding) {
                    Text("不設").tag(Int?.none)
                    ForEach(Self.goalOptions, id: \.self) { goal in
                        Text("\(goal.formatted()) 字").tag(Int?.some(goal))
                    }
                }
            } label: {
                Label(Self.goalMenuTitle(transcript.goalCharacters), systemImage: "target")
            }
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
