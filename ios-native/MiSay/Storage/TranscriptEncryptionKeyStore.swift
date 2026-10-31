import CryptoKit
import Foundation
import Security

/// 方塊 M5：加密歷史檔用的那把金鑰，只存在 Keychain（安全標準二 🔴）。
/// 第一次用時產生；之後都讀同一把。不給任何人看、不進備份（ThisDeviceOnly）。
/// 跟 `APIKeyStore` 長得像但不共用：B1 那個已人驗鎖定，不為了省幾行去動它。
struct TranscriptEncryptionKeyStore {
    enum Failure: Error, Equatable {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
    }

    private static let service = "org.domyweb.misay.transcripts"
    private static let account = "data-key"

    /// 有就讀、沒有就產生一把 256-bit 存進去再回傳。
    func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try read() {
            return existing
        }
        let key = SymmetricKey(size: .bits256)
        try save(key)
        return key
    }

    /// 只給測試用：把金鑰刪掉，讓下一次 loadOrCreateKey 重產。真機上刪了等於所有歷史都讀不回來。
    func deleteForTesting() throws {
        let status = SecItemDelete(Self.query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.saveFailed(status)
        }
    }

    private func read() throws -> SymmetricKey? {
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

    private func save(_ key: SymmetricKey) throws {
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
