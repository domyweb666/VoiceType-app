import SwiftUI
import UniformTypeIdentifiers

/// 「匯出」（2026-11-24 Y1）：這篇帶出去的路全在這裡。複製標題、全文、Markdown；
/// 分享文字、存成文字檔走系統分享；存成 Markdown 到選過的資料夾（K2），還沒選過先跳「檔案」選一個。
struct ExportSheet: View {
    struct Notice: Equatable {
        let glyph: StatusStrip.Glyph
        let message: String
    }

    /// 正文是編輯框裡現在的字，不是上次存檔的。
    let transcript: Transcript
    private let plainText: String

    @Environment(\.dismiss) private var dismiss
    @State private var folderName: String?
    @State private var isPickingFolder = false
    @State private var notice: Notice?
    @State private var copyCount = 0

    static let copyNote = "複製全文不帶標題，也沒有 Markdown 記號。"
        + "貼到能排版的地方，標題、粗體和清單會跟著過去。"

    init(transcript: Transcript) {
        self.transcript = transcript
        plainText = PlainTextExport.text(from: transcript.displayText)
    }

    /// 「存成 Markdown 到「Obsidian」」；還沒選過資料夾是「存成 Markdown…」。
    static func saveTitle(folderName: String?) -> String {
        folderName.map { "存成 Markdown 到「\($0)」" } ?? "存成 Markdown…"
    }

    var body: some View {
        NavigationStack {
            List {
                copySection
                shareSection
                folderSection
            }
            .font(Token.Fonts.body)
            .tint(Token.Colors.link)
            .scrollContentBackground(.hidden)
            .background(Token.Colors.groupedBackground)
            .safeAreaInset(edge: .bottom) { noticeLine }
            .navigationTitle("匯出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .tint(Token.Colors.link)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Token.Shape.radiusSheet)
        .sensoryFeedbackIfEnabled(Token.Haptics.copied, trigger: copyCount)
        .onAppear { folderName = MarkdownFolder().folderName }
        .fileImporter(
            isPresented: $isPickingFolder,
            allowedContentTypes: [.folder],
            onCompletion: pickedFolder
        )
    }
}

private extension ExportSheet {
    var copySection: some View {
        Section {
            if let title = MarkdownExport.title(of: transcript) {
                Button {
                    UIPasteboard.general.string = title
                    copied("標題複製好了")
                } label: {
                    // 不用 textformat：中文系統會畫成「格式」兩個字。
                    Label("複製標題", systemImage: "t.square")
                }
            }
            Button {
                DraftPasteboard.copy(transcript.displayText)
                copied("全文複製好了")
            } label: {
                Label("複製全文", systemImage: "doc.on.doc")
            }
            Button {
                DraftPasteboard.copyMarkdown(transcript.displayText)
                copied("Markdown 複製好了")
            } label: {
                Label("複製成 Markdown", systemImage: "number")
            }
        } footer: {
            Text(Self.copyNote)
                .font(Token.Fonts.footnote)
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    /// 分享給文字：很多 App 的分享表單只收字、不收檔；要存檔的走下面那一項。
    var shareSection: some View {
        Section {
            ShareLink(item: plainText) {
                Label("分享文字", systemImage: "square.and.arrow.up")
            }
            ShareLink(
                item: TranscriptTextFile(transcript: transcript, text: plainText),
                preview: SharePreview(TranscriptTextFile.fileName(for: transcript))
            ) {
                Label("存成文字檔", systemImage: "doc.text")
            }
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    var folderSection: some View {
        Section {
            Button(action: saveMarkdown) {
                Label(
                    Self.saveTitle(folderName: folderName),
                    systemImage: "square.and.arrow.down"
                )
            }
            if folderName != nil {
                Button {
                    isPickingFolder = true
                } label: {
                    Label("換個資料夾…", systemImage: "folder")
                }
            }
        }
        .listRowBackground(Token.Colors.rowBackground)
    }

    @ViewBuilder
    var noticeLine: some View {
        if let notice {
            StatusStrip(glyph: notice.glyph, message: notice.message, isFloating: true)
                .padding(.horizontal, Token.Space.screen)
                .padding(.bottom, Token.Space.s)
        }
    }

    func copied(_ message: String) {
        copyCount += 1
        show(Notice(glyph: .done, message: message))
    }

    func saveMarkdown() {
        guard MarkdownFolder().folderName != nil else {
            isPickingFolder = true
            return
        }
        do {
            let name = try MarkdownFolder().save(transcript)
            show(Notice(glyph: .done, message: "存好了：\(name)"))
        } catch MarkdownFolder.Failure.cannotAccess, MarkdownFolder.Failure.noFolder {
            // 資料夾不見了或權限沒了：請使用者重選。
            isPickingFolder = true
        } catch {
            show(Notice(glyph: .failed, message: "沒存進去，那個資料夾可能滿了或不能寫，換一個試試。"))
        }
    }

    func pickedFolder(_ result: Result<URL, Error>) {
        guard case let .success(folder) = result else {
            return
        }
        do {
            try MarkdownFolder().remember(folder)
        } catch {
            show(Notice(glyph: .failed, message: "打不開這個資料夾，換一個試試。"))
            return
        }
        folderName = MarkdownFolder().folderName
        saveMarkdown()
    }

    /// 講一下就收，跟詳情頁的「已複製」一樣停 2 秒。
    func show(_ newNotice: Notice) {
        notice = newNotice
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if notice == newNotice {
                notice = nil
            }
        }
    }
}
