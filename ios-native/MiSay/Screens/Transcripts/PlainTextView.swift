import SwiftUI
import UIKit

/// 純文字的 UIKit 編輯框（2026-11-15，寫長文第三批，設定 → 進階「新的編輯框（試用）」打開才用）。
/// 為什麼要有：系統的 `TextEditor` 放了游標不保證畫面會捲過去，長稿每打一個字整篇重算，手邊沒有 iPhone 量不出來；
/// 米說繼續往下做、之後一起驗，所以兩種都放著，驗的時候可以切。
/// 跟 v0.2.7 白畫面那個（`MarkdownTextView`，commit 6e0a31a）不一樣的地方：不換字形、不用 TextKit 1、
/// 不邊打邊變樣，只有一種字型一種顏色；`EditorRenderTests` 有一條開著這個開關量畫不畫得出字。
struct PlainTextView: UIViewRepresentable {
    @Binding var text: String
    /// 游標或選取，UTF-16 位置（跟 UITextView 一樣）。
    @Binding var selection: NSRange
    @Binding var isEditing: Bool
    /// 換一個數字，就把游標那裡捲進畫面（大綱與尋找、復原、格式鈕）。
    let scrollToken: Int

    /// 正文的樣子：字型跟著系統字級、行距照設計代號。
    static var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = Token.Space.lineSpacing
        return [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor(Token.Colors.textPrimary),
            .paragraphStyle: paragraph,
        ]
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.tintColor = UIColor(Token.Colors.accent)
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.accessibilityLabel = "文字稿正文"
        Self.setText(text, in: textView)
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
        if textView.text != text {
            Self.setText(text, in: textView)
        }
        let clamped = TextOffsets.clamped(selection, length: (textView.text as NSString).length)
        if textView.selectedRange != clamped {
            textView.selectedRange = clamped
        }
        if coordinator.scrollToken != scrollToken {
            coordinator.scrollToken = scrollToken
            textView.scrollRangeToVisible(clamped)
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

    /// 整份字換掉（一開始、格式鈕、復原、取代、搬動、換回舊版）。打字不走這裡。
    static func setText(_ text: String, in textView: UITextView) {
        textView.attributedText = NSAttributedString(string: text, attributes: attributes)
        textView.typingAttributes = attributes
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PlainTextView
        /// SwiftUI 正把狀態推進編輯框：這時編輯框回報的變動是自己推的，不再寫回去。
        var isApplyingUpdate = false
        var scrollToken = 0

        init(parent: PlainTextView) {
            self.parent = parent
            scrollToken = parent.scrollToken
            super.init()
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingUpdate else {
                return
            }
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingUpdate else {
                return
            }
            parent.selection = textView.selectedRange
            // 游標一動，系統會把「接下來打的字的樣子」換成游標旁邊那個字的；空白頁旁邊沒有字，補回正文的樣子。
            if textView.markedTextRange == nil {
                textView.typingAttributes = PlainTextView.attributes
            }
        }

        func textViewDidBeginEditing(_: UITextView) {
            guard !isApplyingUpdate else {
                return
            }
            parent.isEditing = true
        }

        func textViewDidEndEditing(_: UITextView) {
            guard !isApplyingUpdate else {
                return
            }
            parent.isEditing = false
        }
    }
}

/// 位置換算（純函式，CI 測得到）：UIKit 的編輯框算 UTF-16，米說其他地方都算第幾個字（Character）。
/// 一個 emoji 在 UTF-16 是兩格以上，直接拿來當第幾個字會錯位。
enum TextOffsets {
    /// 不超出字的長度。
    static func clamped(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(0, range.location), length)
        return NSRange(location: location, length: min(max(0, range.length), length - location))
    }

    /// UTF-16 的範圍 → 第幾個字到第幾個字。換不出來（落在半個字上）就當游標在最後面。
    static func characters(of range: NSRange, in text: String) -> Range<Int> {
        let safe = clamped(range, length: text.utf16.count)
        guard let found = Range(safe, in: text) else {
            return text.count ..< text.count
        }
        let start = text.distance(from: text.startIndex, to: found.lowerBound)
        return start ..< start + text.distance(from: found.lowerBound, to: found.upperBound)
    }

    /// 第幾個字到第幾個字 → UTF-16 的範圍。超出就停在最後。
    static func utf16Range(of offsets: Range<Int>, in text: String) -> NSRange {
        let end = text.endIndex
        let start = max(0, offsets.lowerBound)
        let lower = text.index(text.startIndex, offsetBy: start, limitedBy: end) ?? end
        let upper = text.index(lower, offsetBy: offsets.count, limitedBy: end) ?? end
        return NSRange(lower ..< upper, in: text)
    }
}
