import Foundation
import os

/// 方塊 M2 的留存錄音（S2-5）：口語稿存進歷史後，錄音不刪，搬到這裡、用那篇的 id 命名。
/// 漏字時還有原音可以重轉（米最怕的事）。什麼時候可以刪照米 11/07 定的：文字稿存好才算可刪，再留 7 天；
/// 空間剩不到 1 GB 時，有文字稿的可以提早刪；潤飾一直沒成功的不刪；那篇文字稿刪了，錄音跟著刪。
struct RetainedRecordings {
    enum Failure: Error, Equatable {
        case cannotCreateDirectory
        case cannotMoveIn
    }

    static let keepAfterPolishSeconds: TimeInterval = 7 * 24 * 60 * 60
    static let lowSpaceBytes: Int64 = 1_000_000_000

    /// 只記數量（不含內容），規矩檔第 3 節。
    private static let logger = Logger(subsystem: "MiSay", category: "RetainedRecordings")
    private let fileManager = FileManager.default

    func directoryURL() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(path: "Retained", directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: Recorder.fileProtection]
            )
        } catch {
            throw Failure.cannotCreateDirectory
        }
        return directory
    }

    func url(for transcriptID: UUID) throws -> URL {
        try directoryURL().appending(path: transcriptID.uuidString).appendingPathExtension("wav")
    }

    /// K4 起留存錄音可能是 m4a（一直留著的壓過）。
    func m4aURL(for transcriptID: UUID) throws -> URL {
        try directoryURL().appending(path: transcriptID.uuidString).appendingPathExtension("m4a")
    }

    /// 這篇現在留著的那個錄音檔（WAV 或 m4a），沒有就是 nil。
    func existingURL(for transcriptID: UUID) -> URL? {
        let candidates = [try? url(for: transcriptID), try? m4aURL(for: transcriptID)]
        return candidates.compactMap { $0 }.first { fileManager.fileExists(atPath: $0.path) }
    }

    func exists(for transcriptID: UUID) -> Bool {
        existingURL(for: transcriptID) != nil
    }

    /// 重新轉錄要 WAV：留著的是 m4a 就先解回 `<id>.wav`，解好才刪 m4a。之後一直留著的話會再壓回去。
    func wavForRetranscription(of transcriptID: UUID) throws -> URL? {
        let wav = try url(for: transcriptID)
        if fileManager.fileExists(atPath: wav.path) {
            return wav
        }
        let m4a = try m4aURL(for: transcriptID)
        guard fileManager.fileExists(atPath: m4a.path) else {
            return nil
        }
        try AudioCompressor.decodeToWAV(m4a, to: wav)
        try? fileManager.removeItem(at: m4a)
        return wav
    }

    /// K4 一直留著：這篇的 WAV 壓成 m4a（每小時約 14 MB）。先壓到 `.part`，壓完才換名、才刪 WAV：
    /// 壓到一半 App 被殺，原本的 WAV 還在。慢，叫的人要放背景跑，而且要先確定沒人在用這篇。
    func compressKept(_ transcriptID: UUID) {
        guard let wav = try? url(for: transcriptID), let m4a = try? m4aURL(for: transcriptID),
              fileManager.fileExists(atPath: wav.path)
        else {
            return
        }
        let partial = m4a.appendingPathExtension("part")
        do {
            try AudioCompressor.encode(wav, to: partial)
            if fileManager.fileExists(atPath: m4a.path) {
                try fileManager.removeItem(at: m4a)
            }
            try fileManager.moveItem(at: partial, to: m4a)
            try fileManager.removeItem(at: wav)
        } catch {
            // 壓不了就留 WAV：多佔空間，不少聲音。
            try? fileManager.removeItem(at: partial)
        }
    }

    /// 照規則清掉可以刪的。刪不掉的留著下次再試：只佔空間，不影響任何一篇。
    /// 有讀不到的文字稿時，找不到對應那篇的錄音一律不刪：那可能是讀不到的那篇，錄音是它僅剩的一份。
    /// `excluding` 是正在用的那幾篇的 id（例如正在從錄音重新轉錄）：用到一半不刪。
    func purge(
        loaded: TranscriptStore.LoadResult,
        excluding busy: Set<String>,
        keepsForever: Bool = false,
        now: Date = Date()
    ) {
        guard let directory = try? directoryURL(),
              let files = try? fileManager.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: nil
              )
        else {
            return
        }
        let retainedIDs = files.compactMap {
            UUID(uuidString: $0.deletingPathExtension().lastPathComponent)
        }.filter { !busy.contains($0.uuidString) }
        let doomed = Self.idsToDelete(
            retainedIDs: retainedIDs,
            transcripts: loaded.transcripts,
            deletesOrphans: loaded.unreadableCount == 0,
            keepsForever: keepsForever,
            now: now,
            availableBytes: RecordingSpace.availableBytes()
        )
        var failed = 0
        for id in doomed {
            guard let url = existingURL(for: id),
                  (try? fileManager.removeItem(at: url)) != nil
            else {
                failed += 1
                continue
            }
            // 重新轉錄做到一半留下的進度檔，跟錄音一起清；沒有就算了。
            try? fileManager.removeItem(at: RecordingTranscriptionJob.progressURL(for: url))
        }
        if failed > 0 {
            Self.logger.error("留存錄音有 \(failed, privacy: .public) 個刪不掉，下次再試")
        }
    }

    /// 純判斷（CI 測得到）：哪些留存錄音可以刪。
    static func idsToDelete(
        retainedIDs: [UUID],
        transcripts: [Transcript],
        deletesOrphans: Bool,
        keepsForever: Bool = false,
        now: Date,
        availableBytes: Int64?
    ) -> [UUID] {
        let byID = Dictionary(
            transcripts.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let isLowOnSpace = availableBytes.map { $0 < lowSpaceBytes } ?? false
        return retainedIDs.filter { id in
            guard let transcript = byID[id] else {
                return deletesOrphans
            }
            // 潤飾一直沒成功的不刪；設了一直留著的也不刪（只有那篇刪了才刪）。
            guard transcript.draftText != nil, !keepsForever else {
                return false
            }
            let polishedAt = transcript.polishedAt ?? transcript.updatedAt
            return isLowOnSpace || now.timeIntervalSince(polishedAt) >= keepAfterPolishSeconds
        }
    }
}
