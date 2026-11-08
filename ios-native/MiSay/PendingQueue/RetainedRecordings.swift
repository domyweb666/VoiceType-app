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

    func exists(for transcriptID: UUID) -> Bool {
        guard let url = try? url(for: transcriptID) else {
            return false
        }
        return fileManager.fileExists(atPath: url.path)
    }

    /// 待轉錄的錄音搬進來（同一個 volume 是改名）。上一輪搬到一半留下同名檔時，先清掉舊的再搬。
    func retain(recordingAt source: URL, for transcriptID: UUID) throws {
        let destination = try url(for: transcriptID)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            throw Failure.cannotMoveIn
        }
    }

    /// 照規則清掉可以刪的。刪不掉的留著下次再試：只佔空間，不影響任何一篇。
    /// 有讀不到的文字稿時，找不到對應那篇的錄音一律不刪：那可能是讀不到的那篇，錄音是它僅剩的一份。
    /// `excluding` 是正在用的那幾篇的 id（例如正在從錄音重新轉錄）：用到一半不刪。
    func purge(
        loaded: TranscriptStore.LoadResult,
        excluding busy: Set<String>,
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
            now: now,
            availableBytes: RecordingSpace.availableBytes()
        )
        var failed = 0
        for id in doomed {
            guard let url = try? url(for: id), (try? fileManager.removeItem(at: url)) != nil else {
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
            guard transcript.draftText != nil else {
                return false
            }
            let polishedAt = transcript.polishedAt ?? transcript.updatedAt
            return isLowOnSpace || now.timeIntervalSince(polishedAt) >= keepAfterPolishSeconds
        }
    }
}
