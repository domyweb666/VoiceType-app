import CryptoKit
import Foundation
import Security

/// 方塊 M5：以前加密文字稿與進度檔的那把舊金鑰，只拿來讀舊檔（安全標準二，米 2026-11-25 定不另外加密）。
/// 不再產生新的。還沒換成 JSON 的檔要靠它，所以不主動刪，只有「刪除全部資料」才刪。
/// 跟 `APIKeyStore` 長得像但不共用：B1 那個已人驗鎖定，不為了省幾行去動它。
struct TranscriptEncryptionKeyStore {
    enum Failure: Error, Equatable {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
    }

    /// 只給測試用：有值時讀金鑰一律照這個狀態碼失敗，裝成鑰匙圈還沒解鎖。
    var readFailureForTesting: OSStatus?

    private static let service = "org.domyweb.misay.transcripts"
    private static let account = "data-key"

    /// 舊版加密的內容解回原本的 JSON。本來就是 JSON、沒有金鑰、金鑰對不上都回 nil。
    /// 鑰匙圈一時讀不到（開機後還沒解鎖過）丟錯：等一下再試，不准當成壞檔。
    /// 不看第一個 byte 是不是 `{`：密文每 256 個就有一個剛好也是。
    func unseal(_ data: Data) throws -> Data? {
        guard (try? JSONSerialization.jsonObject(with: data)) == nil, let key = try read() else {
            return nil
        }
        return try? AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
    }

    /// 刪除全部資料（S2-9）：文字稿都刪了之後才叫。本來就沒有金鑰也算成功。
    func delete() throws {
        let status = SecItemDelete(Self.query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.saveFailed(status)
        }
    }

    /// 只給測試用：把金鑰刪掉。真機上刪了，還沒換成 JSON 的舊檔就讀不回來。
    func deleteForTesting() throws {
        let status = SecItemDelete(Self.query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.saveFailed(status)
        }
    }

    private func read() throws -> SymmetricKey? {
        if let readFailureForTesting {
            throw Failure.readFailed(readFailureForTesting)
        }
        var query = Self.query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw Failure.readFailed(status)
        }
        guard let data = result as? Data else {
            throw Failure.readFailed(errSecDecode)
        }
        return SymmetricKey(data: data)
    }

    /// 只給測試用：放一把舊金鑰，造舊版的加密檔。
    func saveForTesting(_ key: SymmetricKey) throws {
        var attributes = Self.query
        attributes[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw Failure.saveFailed(status)
        }
    }

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
