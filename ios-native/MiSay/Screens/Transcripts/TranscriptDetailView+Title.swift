import SwiftUI

/// 正文上面那一行標題（2026-11-24 Y4）。存進 `Transcript.title`，跟正文分開：改了停 1 秒就存，離開也存。
/// 標題不跟著正文捲：編輯框自己會捲，外面再包一層捲動，游標會捲不到。打字時只留一行，正文才夠高。
extension TranscriptDetailView {
    static let titleLines = 3

    var titleField: some View {
        TextField(
            "標題",
            text: $titleEdit,
            prompt: Text("標題").foregroundStyle(Token.Colors.textSecondary),
            axis: .vertical
        )
        .font(Token.Fonts.sectionTitle)
        .foregroundStyle(Token.Colors.textPrimary)
        .lineLimit(1 ... (isEditing ? 1 : Self.titleLines))
        .submitLabel(.next)
        .focused($isTitleFocused)
        .onSubmit(moveToBody)
        .onChange(of: titleEdit) { old, new in titleChanged(from: old, to: new) }
        // 「請 AI 看整篇」點了候選標題也會改到：換成那個；自己正在打的不動。
        .onChange(of: transcript.title) { _, title in
            if Self.cleanedTitle(titleEdit) != title {
                titleEdit = title ?? ""
            }
        }
        .padding(.horizontal, Token.Space.screen)
        .padding(.top, Token.Space.s)
    }

    /// 空白就是沒取。
    static func cleanedTitle(_ input: String) -> String? {
        let title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    /// 可以多行的輸入框按「下一步」是打進一個換行：拿掉它，跳到正文。貼進來的好幾行接成一行，不跳。
    static func titleAfterReturn(from old: String, to new: String) -> (text: String, moves: Bool) {
        let lines = new.split(whereSeparator: \.isNewline).map(String.init)
        guard new.contains(where: \.isNewline) else {
            return (new, false)
        }
        if new.filter({ !$0.isNewline }) == old, new.count == old.count + 1 {
            return (old, true)
        }
        return (lines.joined(separator: " "), false)
    }

    private func titleChanged(from old: String, to new: String) {
        let result = Self.titleAfterReturn(from: old, to: new)
        guard result.text == new else {
            titleEdit = result.text
            if result.moves {
                moveToBody()
            }
            return
        }
        titleTask?.cancel()
        titleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.autosaveDelaySeconds))
            guard !Task.isCancelled else {
                return
            }
            flushTitle()
        }
    }

    /// 直接叫正文拿焦點，標題的會自己放掉；先放掉標題的話鍵盤會收下去再升起來。
    private func moveToBody() {
        flushTitle()
        if transcript.draftText == nil {
            isTitleFocused = false
        } else {
            isEditing = true
        }
    }

    /// 還沒有文字稿的篇也能取。只動標題，其他照存檔裡最新的（`updateStored`）。
    func flushTitle() {
        titleTask?.cancel()
        titleTask = nil
        let title = Self.cleanedTitle(titleEdit)
        guard title != transcript.title else {
            titleSaveFailed = false
            return
        }
        do {
            try updateStored {
                $0.title = title
                $0.updatedAt = Date()
            }
            titleSaveFailed = false
        } catch {
            titleSaveFailed = true
        }
    }
}
