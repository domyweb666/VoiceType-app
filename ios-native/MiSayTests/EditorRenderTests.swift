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

    /// 照米的操作走真的詳情頁：打開、點進正文、按完成。只數編輯框那塊的深色點（頂上的金色圖示也算深色）。
    func test詳情頁打開_點進去_按完成_字都在() throws {
        let transcript = Transcript(durationSeconds: 60, rawText: "口語", draftText: sample)
        let detail = NavigationStack {
            TranscriptDetailView(transcript: transcript, onDelete: { _ in })
        }
        .environment(TranscriptionQueue())
        let window = show(detail)
        let textView = try XCTUnwrap(Self.findTextView(in: window), "詳情頁裡找不到編輯框")
        XCTAssertGreaterThan(
            Self.darkPixelCount(in: window, inside: textView),
            200,
            "剛打開：" + Self.describe(textView)
        )
        textView.becomeFirstResponder()
        settle()
        XCTAssertGreaterThan(
            Self.darkPixelCount(in: window, inside: textView),
            200,
            "點進去：" + Self.describe(textView)
        )
        textView.resignFirstResponder()
        settle()
        XCTAssertGreaterThan(
            Self.darkPixelCount(in: window, inside: textView),
            200,
            "按完成：" + Self.describe(textView)
        )
    }

    /// 對照組：同樣的擺法換成系統的 TextEditor（裡面也是 UITextView），確認這套量法本身找得到、畫得出來。
    func test對照組_系統編輯框找得到也畫得出字() throws {
        let window = show(SystemEditorHarness(text: sample))
        let textView = try XCTUnwrap(Self.findTextView(in: window), "對照組也找不到：量法有問題")
        XCTAssertGreaterThan(Self.darkPixelCount(in: window), 200, Self.describe(textView))
    }

    // MARK: 幫手

    private func show(_ view: some View) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
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
        let place = "frame \(textView.frame) contentSize \(textView.contentSize) "
            + "offset \(textView.contentOffset) inset \(textView.adjustedContentInset)"
        let layout = "used \(used) glyphs \(layoutManager.numberOfGlyphs) "
            + "hidden \(textView.isHidden) alpha \(textView.alpha) window \(textView.window != nil)"
        return place + " " + layout + " color \(color) font \(font)"
    }

    /// 灰階低於一半的點（白底上的黑字）。
    private static func darkPixelCount(in window: UIWindow, inside view: UIView? = nil) -> Int {
        let region = view.map { $0.convert($0.bounds, to: window) } ?? window.bounds
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
        let rows = max(0, Int(region.minY)) ..< min(cgImage.height, Int(region.maxY))
        let columns = max(0, Int(region.minX)) ..< min(cgImage.width, Int(region.maxX))
        for row in rows {
            for column in columns {
                let offset = row * cgImage.bytesPerRow + column * bytesPerPixel
                let sum = Int(bytes[offset]) + Int(bytes[offset + 1]) + Int(bytes[offset + 2])
                let gray = sum / 3
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

private struct SystemEditorHarness: View {
    @State var text: String

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
