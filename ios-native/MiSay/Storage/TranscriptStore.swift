import Foundation

/// 方塊 M5：歷史的存、讀全部、改、刪。一篇一個 JSON 檔，不另外加密，靠 iOS 的檔案保護（米 2026-11-25）。
/// v0.2.15 以前的檔用 AES-GCM 加密：讀的時候拿舊金鑰解開，讀全部、讀垃圾桶時順便換成 JSON。
/// 寫檔是原子的（先寫暫存再換名）；讀到壞檔「另存不刪」搬到 Unreadable/，畫面拿得到「有幾篇讀不到」。
/// 復原（E3）、改字自動存（E2）是畫面層用 save 做的事，這裡沒有狀態。
/// 垃圾桶在 `+Trash`、另存的搬回來在 `+Unreadable`，共用這裡的讀檔、寫檔、壞檔另存，所以那幾個函式不加 private。
struct TranscriptStore {
    enum Failure: Error, Equatable {
        case cannotCreateDirectory
        case cannotWrite
        case cannotDelete
        case cannotList
        /// 舊版加密的檔，鑰匙圈一時讀不到（開機後還沒解鎖過）。
        case keychainUnavailable
        /// 檔在，但一時讀不到內容（同上，檔案保護擋著）。
        case cannotRead
        /// 要改、要搬的那一篇已經不在了。
        case notFound
        /// 檔在，但壞了或解不開：不准拿別的內容蓋掉它。
        case unreadable
    }

    /// 讀全部的結果：讀得到的照時間新到舊。
    struct LoadResult: Equatable {
        let transcripts: [Transcript]
        /// 讀不到的共幾篇：搬去 Unreadable/ 的，加上 `blockedCount`。
        let unreadableCount: Int
        /// 一時讀不到、沒有搬走的檔數。
        let blockedCount: Int
    }

    static let fileExtension = "transcript"
    static let unreadableDirectoryName = "Transcripts/Unreadable"
    /// 「第一次解鎖後可用」：背景自動整理（D5）在鎖屏時也要存得進去。
    static let fileProtection = FileProtectionType.completeUntilFirstUserAuthentication
    /// 原子寫入（先寫暫存再換名）＋同一級檔案保護。
    private static let writeOptions: Data.WritingOptions = [
        .atomic,
        .completeFileProtectionUntilFirstUserAuthentication,
    ]

    let fileManager = FileManager.default
    var keyStore = TranscriptEncryptionKeyStore()

    func directoryURL() throws -> URL {
        try ensuredDirectory(named: "Transcripts")
    }

    /// 存一篇（新的或改過的都是整篇蓋寫），原子寫入。
    func save(_ transcript: Transcript) throws {
        try write(transcript, to: fileURL(for: transcript.id))
    }

    /// 讀存檔裡最新的一篇；沒有這個檔回 nil，有檔但讀不到就丟錯。
    func load(id: UUID) throws -> Transcript? {
        try read(fileURL(for: id))
    }

    /// 讀最新的那份、改、存回去：清單手上的可能是舊的，拿舊的存會蓋掉別處剛寫的。
    func update(id: UUID, _ change: (inout Transcript) -> Void) throws {
        guard var transcript = try load(id: id) else {
            throw Failure.notFound
        }
        change(&transcript)
        try save(transcript)
    }

    func read(_ url: URL) throws -> Transcript? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        guard let stored = try storedFile(at: url) else {
            throw Failure.unreadable
        }
        return stored.transcript
    }

    func write(_ transcript: Transcript, to url: URL) throws {
        let json: Data
        do {
            json = try Self.encoder.encode(transcript)
        } catch {
            throw Failure.cannotWrite
        }
        try protectExistingFile(at: url)
        do {
            try json.write(to: url, options: Self.writeOptions)
        } catch {
            throw Failure.cannotWrite
        }
    }

    /// 讀全部，舊版加密的檔順便換成 JSON。壞掉的檔搬去 Unreadable/（不刪），現在解得開的順便搬回來。
    /// 某一篇一時讀不到就留在原位、算進讀不到的篇數，其他照讀；留存錄音看到有讀不到的就不清孤兒。
    /// 一篇都沒讀到（開機後還沒解鎖過）才丟錯：空的清單會讓人以為全沒了。
    func loadAll() throws -> LoadResult {
        restoreSetAside()
        var transcripts: [Transcript] = []
        var setAsideCount = 0
        var blockedCount = 0
        for file in try transcriptFiles(in: directoryURL()) {
            do {
                if let transcript = try readReplacingSealed(file) {
                    transcripts.append(transcript)
                } else {
                    setAsideCount += 1
                    try? setAside(file)
                }
            } catch Failure.cannotRead {
                blockedCount += 1
            }
        }
        guard blockedCount == 0 || !transcripts.isEmpty else {
            throw Failure.cannotRead
        }
        transcripts.sort { $0.createdAt > $1.createdAt }
        // 以前搬走的也要算：不然從詳情頁返回、再讀一次，數字就變 0、橫幅不見了。
        return LoadResult(
            transcripts: transcripts,
            unreadableCount: blockedCount + max(setAsideCount, setAsideFileCount()),
            blockedCount: blockedCount
        )
    }

    /// 清單裡有哪些篇，只看檔名：一時讀不到的那幾篇也算在內。
    func listedIDs() throws -> Set<UUID> {
        try Self.ids(of: transcriptFiles(in: directoryURL()))
    }

    static func ids(of files: [URL]) -> Set<UUID> {
        Set(files.compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) })
    }

    func transcriptFiles(in directory: URL) throws -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == Self.fileExtension }
        } catch {
            throw Failure.cannotList
        }
    }

    /// 真的把那一篇的檔刪掉，不進垃圾桶。使用者自己刪的走 `moveToTrash`；
    /// 這裡給程式自己收拾的（接著錄併掉的暫時篇、空白新文稿）。
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

    func fileURL(for id: UUID) throws -> URL {
        try directoryURL().appending(path: id.uuidString).appendingPathExtension(Self.fileExtension)
    }

    /// 壞檔另存不刪（PRD「歷史檔讀不到的時候 App 不會自己清空」）。
    func setAside(_ file: URL) throws {
        let unreadable = try ensuredDirectory(named: Self.unreadableDirectoryName)
        var destination = unreadable.appending(path: file.lastPathComponent)
        // 同一篇以前搬過一次：兩份都留。
        if fileManager.fileExists(atPath: destination.path) {
            destination = unreadable.appending(path: "\(UUID())-\(file.lastPathComponent)")
        }
        try fileManager.moveItem(at: file, to: destination)
    }

    func ensuredDirectory(named name: String) throws -> URL {
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

/// 讀檔：先當 JSON，不是 JSON 才用舊金鑰解。文字稿一律在主執行緒讀寫，換檔才不會跟存檔、刪除交錯。
extension TranscriptStore {
    /// 一個檔解出來的樣子。`bytes` 跟 `json` 不一樣就是舊版加密的。
    private struct StoredFile {
        let transcript: Transcript
        let bytes: Data
        let json: Data
    }

    /// nil 是真的壞了或解不開，可以另存。一時讀不到（檔案保護、鑰匙圈還沒解鎖）丟錯，不准當壞檔搬走。
    private func storedFile(at file: URL) throws -> StoredFile? {
        let bytes: Data
        do {
            bytes = try Data(contentsOf: file)
        } catch {
            throw Failure.cannotRead
        }
        if let transcript = try? Self.decoder.decode(Transcript.self, from: bytes) {
            return StoredFile(transcript: transcript, bytes: bytes, json: bytes)
        }
        guard let json = try unseal(bytes),
              let transcript = try? Self.decoder.decode(Transcript.self, from: json)
        else {
            return nil
        }
        return StoredFile(transcript: transcript, bytes: bytes, json: json)
    }

    private func unseal(_ bytes: Data) throws -> Data? {
        do {
            return try keyStore.unseal(bytes)
        } catch {
            throw Failure.keychainUnavailable
        }
    }

    /// 讀一個檔；舊版加密的順便換成 JSON。寫回去的是解出來的原始內容，不重新編碼，免得掉欄位。
    func readReplacingSealed(_ file: URL) throws -> Transcript? {
        guard let stored = try storedFile(at: file) else {
            return nil
        }
        // 寫回前再看一次：檔被換過、刪掉了就不寫，不拿舊內容蓋新的。
        if stored.json != stored.bytes, (try? Data(contentsOf: file)) == stored.bytes {
            // 寫不進去就留著加密的，下次再換；這次讀到的照樣算數。
            try? stored.json.write(to: file, options: Self.writeOptions)
        }
        return stored.transcript
    }

    /// 蓋掉之前先看現在那份：一時讀不到就丟錯不蓋，壞的先另存再蓋。
    /// 以前存檔也要金鑰，讀不到的時候存不進去，剛好擋著；現在要自己擋。
    private func protectExistingFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path), try storedFile(at: url) == nil else {
            return
        }
        do {
            try setAside(url)
        } catch {
            throw Failure.cannotWrite
        }
    }
}
