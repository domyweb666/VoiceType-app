import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// 分享用的純文字檔（E5）：系統分享表單對「檔案」才會出現「儲存到檔案」。
/// 暫存檔開檔案保護；放在 tmp，由系統清。
struct TranscriptTextFile: Transferable {
    let transcript: Transcript
    let text: String

    /// 有標題就接在日期後面，存進「檔案」才認得出是哪篇。
    static func fileName(for transcript: Transcript) -> String {
        let date = transcript.createdAt.formatted(.iso8601.year().month().day())
        guard let title = MarkdownExport.title(of: transcript) else {
            return date + ".txt"
        }
        let limit = MarkdownExport.fileNameTitleLength
        return date + " " + MarkdownExport.fileNamePart(title, limit: limit) + ".txt"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            let name = Self.fileName(for: file.transcript)
            let url = FileManager.default.temporaryDirectory.appending(path: name)
            try Data(file.text.utf8).write(to: url, options: [.atomic, .completeFileProtection])
            return SentTransferredFile(url)
        }
    }
}
