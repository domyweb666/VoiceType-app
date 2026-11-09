import CoreText
import SwiftUI
import UIKit

/// 文字稿正文的編輯框（2026-11-09）。SwiftUI 的 TextEditor 不能讓一段字換字型，標題、粗體只能看到記號，
/// 所以換成 UIKit 的 UITextView：存的還是純文字，樣子照 `MarkdownStyler` 畫，清單的 `-` 換成圓點畫。
/// 上緣留一點白（米 11/09：第一行貼著頂上那排太近）。
/// 用 TextKit 1（`usingTextLayoutManager: false`）：圓點要在排字時換掉 `-` 那個字形，TextKit 2 沒有這個接口。
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    /// 游標或選取，UTF-16 位置（跟 UITextView 一樣）。
    @Binding var selection: NSRange
    @Binding var isEditing: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: false)
        textView.layoutManager.delegate = context.coordinator
        textView.textStorage.delegate = context.coordinator
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.tintColor = Token.Editor.cursor
        textView.typingAttributes = MarkdownStyler.baseAttributes
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(
            top: Token.Space.m,
            left: Token.Space.l,
            bottom: Token.Space.l,
            right: Token.Space.l
        )
        textView.accessibilityLabel = "文字稿正文"
        textView.text = text
        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        // 注音還在選字時不動它：換字或移游標會把選到一半的字打斷。
        guard textView.markedTextRange == nil else {
            return
        }
        coordinator.isApplyingUpdate = true
        defer { coordinator.isApplyingUpdate = false }
        if textView.textStorage.string != text {
            Self.replaceChangedPart(of: textView, with: text)
        }
        let length = textView.textStorage.length
        let location = min(max(0, selection.location), length)
        let clamped = NSRange(location: location, length: min(selection.length, length - location))
        if textView.selectedRange != clamped {
            textView.selectedRange = clamped
        }
        if isEditing, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isEditing, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// 只換前後不一樣的那段（格式鈕、「改這段」換上）：整篇重設會跳回頂端，也會清掉復原紀錄。
    /// 走 `replace(_:withText:)`，按「復原」退得回去。
    static func replaceChangedPart(of textView: UITextView, with newText: String) {
        let old = textView.textStorage.string as NSString
        let new = newText as NSString
        let shorter = min(old.length, new.length)
        var prefix = 0
        while prefix < shorter, old.character(at: prefix) == new.character(at: prefix) {
            prefix += 1
        }
        let oldLast = old.length - 1
        let newLast = new.length - 1
        func isSameFromEnd(_ distance: Int) -> Bool {
            old.character(at: oldLast - distance) == new.character(at: newLast - distance)
        }
        var suffix = 0
        while suffix < shorter - prefix, isSameFromEnd(suffix) {
            suffix += 1
        }
        // 不要從一個 emoji 的中間切開（UTF-16 的一對代理字元）。
        if prefix > 0, UTF16.isLeadSurrogate(old.character(at: prefix - 1)) {
            prefix -= 1
        }
        if suffix > 0, UTF16.isTrailSurrogate(old.character(at: old.length - suffix)) {
            suffix -= 1
        }
        let replacement = new.substring(
            with: NSRange(location: prefix, length: new.length - prefix - suffix)
        )
        guard let start = textView.position(from: textView.beginningOfDocument, offset: prefix),
              let end = textView.position(from: start, offset: old.length - prefix - suffix),
              let range = textView.textRange(from: start, to: end)
        else {
            textView.text = newText
            return
        }
        textView.replace(range, withText: replacement)
    }
}
