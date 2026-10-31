import SwiftUI

/// 設定 →「資料」（片 G1、G2）：匯出備份、匯入備份。
/// 匯入合併不覆蓋：同一篇（同 id）已經在手機上就跳過；先講清楚會加幾篇，按了才寫（安全標準六）。
struct BackupSection: View {
    @State private var transcriptCount = 0
    @State private var isImporting = false
    @State private var pendingImport: [Transcript] = []
    @State private var skippedCount = 0
    @State private var isConfirmingImport = false
    @State private var resultMessage: String?

    var body: some View {
        Section {
            ShareLink(
                item: BackupFile(),
                preview: SharePreview(BackupFile.fileName)
            ) {
                Text("匯出備份")
            }
            .tint(Token.Colors.link)
            .disabled(transcriptCount == 0)
            // 讀篇數、選檔、確認框掛在這顆鈕上：掛在 Section 上，SwiftUI 可能每一列各套一次。
            Button("匯入備份") {
                resultMessage = nil
                isImporting = true
            }
            .tint(Token.Colors.link)
            .task { reloadCount() }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                prepareImport(result)
            }
            .confirmationDialog(
                Self.confirmTitle(adding: pendingImport.count, skipping: skippedCount),
                isPresented: $isConfirmingImport,
                titleVisibility: .visible
            ) {
                Button("加入 \(pendingImport.count) 篇") { commitImport() }
                Button("取消", role: .cancel) { pendingImport = [] }
            }
            if let resultMessage {
                Text(resultMessage)
                    .font(Token.Fonts.secondary)
                    .foregroundStyle(Token.Colors.textPrimary)
            }
        } header: {
            Text("資料")
        } footer: {
            Text(footerText)
                .font(Token.Fonts.footnote)
        }
        .font(Token.Fonts.body)
        .listRowBackground(Token.Colors.rowBackground)
    }

    /// 沒東西時按鈕變灰，這裡說為什麼。
    private var footerText: String {
        let lead = transcriptCount == 0
            ? "還沒有文字稿可以備份。"
            : "備份是一個檔，裡面是全部 \(transcriptCount) 篇文字稿，不含金鑰；新手機要重貼金鑰。"
        return lead + "備份檔沒有加密，存在只有自己拿得到的地方。"
    }

    static func confirmTitle(adding newCount: Int, skipping skipped: Int) -> String {
        let skippedText = skipped > 0 ? "手機上已經有的 \(skipped) 篇跳過，" : ""
        return "會加入 \(newCount) 篇，\(skippedText)現有的文字稿不會被改。"
    }

    /// 匯入擋下來時講是哪一關，最後都說「沒有匯入」：手機上的東西沒動。
    static func message(for failure: Backup.Failure) -> String {
        switch failure {
        case .tooLarge:
            "沒有匯入：這個檔超過 50 MB，不像米說的備份。"
        case .notABackup:
            "沒有匯入：這不是米說的備份檔。"
        case .newerVersion:
            "沒有匯入：這個備份是新版米說做的，先更新米說。"
        case .unreadable:
            "沒有匯入：備份檔裡面壞了，讀不出文字稿。"
        }
    }

    private func reloadCount() {
        // 讀不到歷史時當 0 篇，匯出鈕變灰；文字稿清單那頁會講讀不到。
        transcriptCount = (try? TranscriptStore().loadAll().transcripts.count) ?? 0
    }

    /// 讀檔、驗格式、算要加幾篇；這一步不寫任何東西。
    private func prepareImport(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else {
            // 使用者在選檔畫面按取消也會走這裡，不報錯。
            return
        }
        let backup: Backup
        do {
            backup = try Backup.decode(Self.readSelectedFile(at: url))
        } catch let failure as Backup.Failure {
            resultMessage = Self.message(for: failure)
            return
        } catch {
            resultMessage = "沒有匯入：讀不到這個檔。"
            return
        }
        let existingIDs: Set<UUID>
        do {
            existingIDs = try Set(TranscriptStore().loadAll().transcripts.map(\.id))
        } catch {
            // 不知道手機上有哪些，就不知道會不會重複，寧可不匯。
            resultMessage = "沒有匯入：手機上的文字稿讀不到，不知道會不會重複。"
            return
        }
        pendingImport = backup.newTranscripts(existingIDs: existingIDs)
        skippedCount = backup.transcripts.count - pendingImport.count
        guard !pendingImport.isEmpty else {
            resultMessage = "這個備份裡的文字稿手機上都有了，沒有要加的。"
            return
        }
        isConfirmingImport = true
    }

    /// 一篇一篇存；中途存不進去就停，已經加的留著（再匯入一次會跳過它們接著加）。
    private func commitImport() {
        let store = TranscriptStore()
        var addedCount = 0
        for transcript in pendingImport {
            do {
                try store.save(transcript)
                addedCount += 1
            } catch {
                resultMessage = "加了 \(addedCount) 篇，之後的存不進去。再匯入一次會接著加。"
                pendingImport = []
                reloadCount()
                return
            }
        }
        resultMessage = "加好了，多了 \(addedCount) 篇。"
        pendingImport = []
        reloadCount()
    }

    /// 「檔案」選回來的是別的 App 的位置，要先拿到存取權；大小在讀之前就先看，太大的不讀進記憶體。
    private static func readSelectedFile(at url: URL) throws -> Data {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= Backup.maxImportBytes else {
            throw Backup.Failure.tooLarge
        }
        return try Data(contentsOf: url)
    }
}
