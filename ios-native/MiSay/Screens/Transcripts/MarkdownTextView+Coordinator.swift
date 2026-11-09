import CoreText
import UIKit

/// 編輯框的三個代理：字改了回報給 SwiftUI、改到的那幾行重新上樣式、排字時把清單的 `-` 換成圓點。
extension MarkdownTextView {
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: UITextView?
        /// SwiftUI 正把狀態推進編輯框：這時編輯框回報的變動是自己推的，不再寫回去（寫回去會在畫面更新中改狀態）。
        var isApplyingUpdate = false
        /// 注音選字時改到、還沒上樣式的範圍：選完字再一起上。
        var deferredRange: NSRange?

        init(parent: MarkdownTextView) {
            self.parent = parent
            super.init()
            // 系統字級換了，已經上好的字型不會自己跟著變，整篇重上一次。
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(contentSizeChanged),
                name: UIContentSizeCategory.didChangeNotification,
                object: nil
            )
        }

        // MARK: UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            applyDeferredStyle()
            guard !isApplyingUpdate else {
                return
            }
            parent.text = textView.textStorage.string
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            applyDeferredStyle()
            guard !isApplyingUpdate else {
                return
            }
            parent.selection = textView.selectedRange
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

        private func applyDeferredStyle() {
            guard let range = deferredRange, let textView, textView.markedTextRange == nil else {
                return
            }
            deferredRange = nil
            restyle(textView.textStorage, around: range)
        }

        @objc private func contentSizeChanged() {
            guard let textView else {
                return
            }
            textView.typingAttributes = MarkdownStyler.baseAttributes
            let whole = NSRange(location: 0, length: textView.textStorage.length)
            restyle(textView.textStorage, around: whole)
        }

        private func restyle(_ storage: NSTextStorage, around range: NSRange) {
            storage.beginEditing()
            MarkdownStyler.apply(to: storage, around: range)
            storage.endEditing()
        }
    }
}

extension MarkdownTextView.Coordinator: NSTextStorageDelegate {
    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorage.EditActions,
        range editedRange: NSRange,
        changeInLength _: Int
    ) {
        // 只有字變了才重上；自己上樣式也會走到這裡（只動屬性），不能再上一次。
        guard editedMask.contains(.editedCharacters) else {
            return
        }
        if textView?.markedTextRange != nil {
            deferredRange = deferredRange.map { NSUnionRange($0, editedRange) } ?? editedRange
            return
        }
        MarkdownStyler.apply(to: textStorage, around: editedRange)
    }
}

extension MarkdownTextView.Coordinator: NSLayoutManagerDelegate {
    // 六個參數是系統代理方法的樣子，改不了，只對這個方法關掉參數數量檢查。
    // swiftlint:disable function_parameter_count
    /// 行首的 `- ` 那個 `-` 畫成圓點；字本身不變，複製、存檔照樣是 `-`。
    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font aFont: UIFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard let string = layoutManager.textStorage?.string as NSString?,
              let bullet = Self.bulletGlyph(in: aFont)
        else {
            return 0
        }
        let markerIndexes = (0 ..< glyphRange.length).filter {
            MarkdownStyler.isListMarker(at: charIndexes[$0], in: string)
        }
        guard !markerIndexes.isEmpty else {
            return 0
        }
        var replaced = Array(UnsafeBufferPointer(start: glyphs, count: glyphRange.length))
        for index in markerIndexes {
            replaced[index] = bullet
        }
        layoutManager.setGlyphs(
            replaced,
            properties: props,
            characterIndexes: charIndexes,
            font: aFont,
            forGlyphRange: glyphRange
        )
        return glyphRange.length
    }

    // swiftlint:enable function_parameter_count

    private static func bulletGlyph(in font: UIFont) -> CGGlyph? {
        var character: UniChar = 0x2022 // •
        var glyph: CGGlyph = 0
        guard CTFontGetGlyphsForCharacters(font as CTFont, &character, &glyph, 1), glyph != 0 else {
            return nil
        }
        return glyph
    }
}
