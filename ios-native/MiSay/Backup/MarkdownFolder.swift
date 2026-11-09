import Foundation

/// K2：Markdown 存到哪個資料夾。使用者在「檔案」選過一次，記住它（書籤），下次一鍵存。
/// 書籤不是秘密（只是資料夾在哪），放 UserDefaults。資料夾不見了或權限沒了，就請使用者重選。
struct MarkdownFolder {
    enum Failure: Error, Equatable {
        case noFolder
        case cannotAccess
        case cannotWrite
    }

    private static let bookmarkKey = "markdownFolderBookmark"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 選了的資料夾名字（「Obsidian」之類），沒選過是 nil。
    var folderName: String? {
        resolvedURL()?.lastPathComponent
    }

    /// 從「檔案」選資料夾回來的那個網址：要先拿到存取權才建得出書籤。
    func remember(_ folder: URL) throws {
        guard folder.startAccessingSecurityScopedResource() else {
            throw Failure.cannotAccess
        }
        defer { folder.stopAccessingSecurityScopedResource() }
        do {
            let bookmark = try folder.bookmarkData()
            defaults.set(bookmark, forKey: Self.bookmarkKey)
        } catch {
            throw Failure.cannotAccess
        }
    }

    /// 存一篇，回存好的檔名。同名的已經在了就加「 (2)」，不蓋掉別的檔。
    @discardableResult
    func save(_ transcript: Transcript) throws -> String {
        guard let folder = resolvedURL() else {
            throw Failure.noFolder
        }
        guard folder.startAccessingSecurityScopedResource() else {
            throw Failure.cannotAccess
        }
        defer { folder.stopAccessingSecurityScopedResource() }
        let url = Self.freeURL(in: folder, named: MarkdownExport.fileName(for: transcript))
        do {
            try Data(MarkdownExport.content(for: transcript).utf8).write(to: url, options: .atomic)
        } catch {
            throw Failure.cannotWrite
        }
        return url.lastPathComponent
    }

    private func resolvedURL() -> URL? {
        guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else {
            return nil
        }
        var isStale = false
        let resolved = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
        guard let url = resolved else {
            return nil
        }
        // 書籤舊了（資料夾搬過）：趁還打得開時換一份新的，下次才不會失效。
        if isStale {
            try? remember(url)
        }
        return url
    }

    private static func freeURL(in folder: URL, named name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        var candidate = folder.appending(path: name)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appending(path: "\(base) (\(number)).md")
            number += 1
        }
        return candidate
    }
}
