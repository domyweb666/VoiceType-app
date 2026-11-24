import CryptoKit
import Foundation

/// 2026-11-25：金鑰跟 iCloud 鑰匙圈走之後，一個檔可能是別把金鑰加密的；
/// 新手機上鑰匙圈也可能比文字稿晚到，先被當壞檔搬走的要放得回來。
extension TranscriptStore {
    /// 先用這台那一把，打不開再試其他把；試成的那把本機留一份。
    func open(_ file: URL, using key: SymmetricKey) -> Transcript? {
        if let transcript = Self.decrypt(file, using: key) {
            return transcript
        }
        for other in keyStore.otherKeys() {
            if let transcript = Self.decrypt(file, using: other) {
                keyStore.keep(other)
                return transcript
            }
        }
        return nil
    }

    /// 搬去 Unreadable/ 的檔現在打得開了就放回原處（清單或垃圾桶）。
    /// 那裡已經有同一篇就不動，不蓋任何一份；搬不動留著，下次再試。
    func restoreSetAside(using key: SymmetricKey) {
        guard let files = try? setAsideFiles() else {
            return
        }
        for file in files {
            guard let transcript = open(file, using: key),
                  let listed = try? fileURL(for: transcript.id),
                  let trashed = try? trashURL(for: transcript.id),
                  !fileManager.fileExists(atPath: listed.path),
                  !fileManager.fileExists(atPath: trashed.path)
            else {
                continue
            }
            let destination = transcript.trashedAt == nil ? listed : trashed
            do {
                try fileManager.moveItem(at: file, to: destination)
                DiagnosticLog.shared.record("讀不到的一篇現在打得開了，放回來")
            } catch {
                DiagnosticLog.shared.record("讀不到的一篇放不回來 \(type(of: error))")
            }
        }
    }
}
