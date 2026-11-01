import CryptoKit
import Foundation

/// 方塊 M5：歷史的存、讀全部、改、刪。一篇一個檔，AES-GCM 加密後落地，金鑰在 Keychain。
/// 寫檔是原子的（先寫暫存再換名）；讀到壞檔「另存不刪」搬到 Unreadable/，畫面拿得到「有幾篇讀不到」。
/// 復原（E3）、改字自動存（E2）是畫面層用 save 做的事，這裡沒有狀態。
struct TranscriptStore {
    enum Failure: Error, Equatable {
        case cannotCreateDirectory
        case cannotWrite
        case cannotDelete
        case cannotList
        case keychainUnavailable
    }

    /// 讀全部的結果：讀得到的照時間新到舊；讀不到的檔數（原檔已搬到 Unreadable/）。
    struct LoadResult: Equatable {
        let transcripts: [Transcript]
        let unreadableCount: Int
    }

    static let fileExtension = "transcript"
    private static let unreadableDirectoryName = "Transcripts/Unreadable"
    /// 「第一次解鎖後可用」：背景自動整理（D5）在鎖屏時也要存得進去。加密另外靠 CryptoKit。
    static let fileProtection = FileProtectionType.completeUntilFirstUserAuthentication
    /// 原子寫入（先寫暫存再換名）＋同一級檔案保護。
    private static let writeOptions: Data.WritingOptions = [
        .atomic,
        .completeFileProtectionUntilFirstUserAuthentication,
    ]

    private let fileManager = FileManager.default
    private let keyStore = TranscriptEncryptionKeyStore()

    func directoryURL() throws -> URL {
        try ensuredDirectory(named: "Transcripts")
    }

    /// 存一篇（新的或改過的都是整篇蓋寫）。先加密、再原子寫入。
    func save(_ transcript: Transcript) throws {
        let key = try loadKey()
        let plaintext: Data
        do {
            plaintext = try Self.encoder.encode(transcript)
        } catch {
            throw Failure.cannotWrite
        }
        guard let sealed = try? AES.GCM.seal(plaintext, using: key).combined else {
            throw Failure.cannotWrite
        }
        let url = try fileURL(for: transcript.id)
        do {
            try sealed.write(to: url, options: Self.writeOptions)
        } catch {
            throw Failure.cannotWrite
        }
    }

    /// 讀全部。解不開的檔搬去 Unreadable/（不刪），數量回報給畫面。
    func loadAll() throws -> LoadResult {
        let key = try loadKey()
        let directory = try directoryURL()
        let files: [URL]
        do {
            files = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
        } catch {
            throw Failure.cannotList
        }
        var transcripts: [Transcript] = []
        var unreadableCount = 0
        for file in files where file.pathExtension == Self.fileExtension {
            if let transcript = Self.decrypt(file, using: key) {
                transcripts.append(transcript)
            } else {
                unreadableCount += 1
                try? setAside(file)
            }
        }
        transcripts.sort { $0.createdAt > $1.createdAt }
        // 以前搬走的也要算：不然從詳情頁返回、再讀一次，數字就變 0、橫幅不見了。
        let totalUnreadable = max(unreadableCount, setAsideFileCount())
        return LoadResult(transcripts: transcripts, unreadableCount: totalUnreadable)
    }

    /// Unreadable/ 裡現有幾個檔。數不到就當 0：只影響橫幅的數字，不影響任何資料。
    private func setAsideFileCount() -> Int {
        do {
            let unreadable = try ensuredDirectory(named: Self.unreadableDirectoryName)
            let files = try fileManager.contentsOfDirectory(
                at: unreadable,
                includingPropertiesForKeys: nil
            )
            return files.filter { $0.pathExtension == Self.fileExtension }.count
        } catch {
            return 0
        }
    }

    /// 真的把那一篇的檔刪掉。畫面要先給 5 秒復原的機會（E3）才呼叫。
    func delete(id: UUID) throws {
        let url = try fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw Failure.cannotDelete
        }
    }

    private func loadKey() throws -> SymmetricKey {
        do {
            return try keyStore.loadOrCreateKey()
        } catch {
            throw Failure.keychainUnavailable
        }
    }

    private func fileURL(for id: UUID) throws -> URL {
        try directoryURL().appending(path: id.uuidString).appendingPathExtension(Self.fileExtension)
    }

    /// 壞檔另存不刪（PRD「歷史檔讀不到的時候 App 不會自己清空」）。
    private func setAside(_ file: URL) throws {
        let unreadable = try ensuredDirectory(named: Self.unreadableDirectoryName)
        try fileManager.moveItem(at: file, to: unreadable.appending(path: file.lastPathComponent))
    }

    private func ensuredDirectory(named name: String) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(path: name, directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: Self.fileProtection]
            )
        } catch {
            throw Failure.cannotCreateDirectory
        }
        return directory
    }

    private static func decrypt(_ file: URL, using key: SymmetricKey) -> Transcript? {
        guard let combined = try? Data(contentsOf: file),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let plaintext = try? AES.GCM.open(
                  box,
                  using: key
              )
        else {
            return nil
        }
        return try? decoder.decode(Transcript.self, from: plaintext)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
