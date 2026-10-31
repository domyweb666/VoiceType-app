import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// 分享用的純文字檔（E5）：系統分享表單對「檔案」才會出現「儲存到檔案」。
/// 暫存檔開檔案保護；放在 tmp，由系統清。
struct TranscriptTextFile: Transferable {
    let transcript: Transcript
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            let name = file.transcript.createdAt.formatted(.iso8601.year().month().day()) + ".txt"
            let url = FileManager.default.temporaryDirectory.appending(path: name)
            try Data(file.text.utf8).write(to: url, options: [.atomic, .completeFileProtection])
            return SentTransferredFile(url)
        }
    }
}
