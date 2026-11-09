@testable import MiSay
import SwiftUI
import XCTest

/// 2026-11-10 米真機：v0.2.7 打開文字稿，正文一片白（字數照樣是 64 字）。
/// 單元測試看不到畫面，所以這裡把編輯框真的放進視窗、畫成圖，數深色的點：有畫出字，深色點就會有幾百個。
@MainActor
final class EditorRenderTests: XCTestCase {
    private let sample = "等一下我就是，東西提交完之後我去睡覺。睡飽之後就洗澡，洗完澡，就趕快散步，寫完心理法則。"

    func test編輯框放進視窗畫得出字() throws {
        let window = show(EditorHarness(text: sample))
        let textView = try XCTUnwrap(Self.findTextView(in: window), "視窗裡找不到編輯框")
        let summary = Self.describe(textView)
        XCTAssertEqual(textView.textStorage.string, sample, summary)
        XCTAssertGreaterThan(textView.bounds.height, 100, summary)
        XCTAssertGreaterThan(Self.darkPixelCount(in: window), 200, summary)
    }

    func test點進去打字之後還畫得出字() throws {
        let window = show(EditorHarness(text: sample))
        let textView = try XCTUnwrap(Self.findTextView(in: window), "視窗裡找不到編輯框")
        textView.becomeFirstResponder()
        textView.selectedRange = NSRange(location: 3, length: 0)
        textView.insertText("好")
        settle()
        let summary = Self.describe(textView)
        XCTAssertTrue(textView.textStorage.string.contains("好"), summary)
        XCTAssertGreaterThan(Self.darkPixelCount(in: window), 200, summary)
    }

    // MARK: 幫手

    private func show(_ view: some View) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        settle()
        return window
    }

    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    }

    private static func findTextView(in view: UIView) -> UITextView? {
        if let textView = view as? UITextView {
            return textView
        }
        return view.subviews.lazy.compactMap { findTextView(in: $0) }.first
    }

    /// 失敗時印出來的現況：位置、內容大小、排好的字佔多大、第一個字的顏色與字型。
    private static func describe(_ textView: UITextView) -> String {
        let layoutManager = textView.layoutManager
        layoutManager.ensureLayout(for: textView.textContainer)
        let used = layoutManager.usedRect(for: textView.textContainer)
        let storage = textView.textStorage
        let attributes = storage.length > 0 ? storage.attributes(at: 0, effectiveRange: nil) : [:]
        let color = attributes[.foregroundColor].map { "\($0)" } ?? "nil"
        let font = attributes[.font].map { "\($0)" } ?? "nil"
        return "frame \(textView.frame) bounds \(textView.bounds) contentSize \(textView.contentSize) "
            + "offset \(textView.contentOffset) inset \(textView.adjustedContentInset) used \(used) "
            + "glyphs \(layoutManager.numberOfGlyphs) hidden \(textView.isHidden) alpha \(textView.alpha) "
            + "color \(color) font \(font) window \(textView.window != nil)"
    }

    /// 灰階低於一半的點（白底上的黑字）。
    private static func darkPixelCount(in window: UIWindow) -> Int {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard let cgImage = image.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else {
            return 0
        }
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        var count = 0
        for row in 0 ..< cgImage.height {
            for column in 0 ..< cgImage.width {
                let offset = row * cgImage.bytesPerRow + column * bytesPerPixel
                let gray = (Int(bytes[offset]) + Int(bytes[offset + 1]) + Int(bytes[offset + 2])) / 3
                if gray < 128 {
                    count += 1
                }
            }
        }
        return count
    }
}

/// 照詳情頁的擺法：底色、字數那行都不要，只看編輯框本身。
private struct EditorHarness: View {
    @State var text: String
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            DraftEditor(
                text: $text,
                isEditing: $isEditing,
                canRecordHere: true,
                onRecordHere: { _ in }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Token.Colors.rowBackground)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
