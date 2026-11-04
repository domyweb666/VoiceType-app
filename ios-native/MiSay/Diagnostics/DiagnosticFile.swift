import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// 給 ShareLink 用：按下分享才組檔。暫存檔開檔案保護；放在 tmp，由系統清。
struct DiagnosticFile: Transferable {
    static let fileName = "米說診斷紀錄.txt"

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { _ in
            let url = FileManager.default.temporaryDirectory.appending(path: fileName)
            let data = Data(DiagnosticLog.shared.exportedText().utf8)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return SentTransferredFile(url)
        }
    }
}
