import Foundation
import Security

/// 方塊 M6：OpenAI 金鑰只准走這裡（安全標準一 🔴）。
/// 只做存、讀、刪。不驗證金鑰（片 B2）、不連網、沒有畫面（片 B3）。
/// 金鑰的內容不准出現在錯誤、log、測試輸出裡，所以 Failure 只帶系統狀態碼。
struct APIKeyStore {
    enum Failure: Error, Equatable {
        case emptyKey
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)
    }

    /// Keychain 裡這一筆的身分，不是秘密；秘密是值。
    private static let service = "org.domyweb.misay.openai"
    private static let account = "api-key"

    /// 存之前去掉前後空白：貼上時多帶一個換行是「金鑰明明對卻說錯」最常見的原因。
    func save(_ rawKey: String) throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw Failure.emptyKey }

        // 先刪舊的再加新的，比 SecItemUpdate 少一條分支；兩步都要成功才算存好。
        let deleteStatus = SecItemDelete(Self.query as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw Failure.saveFailed(deleteStatus)
        }

        var attributes = Self.query
        attributes[kSecValueData as String] = Data(key.utf8)
        // 只在這台裝置、解鎖後可用：不進 iCloud 備份，換手機要重貼（PRD 備份那條）。
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.saveFailed(status) }
    }

    /// 沒存過回 nil（第一次打開本來就沒有，不算錯）；Keychain 出錯才拋。
    func read() throws -> String? {
        var query = Self.query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure.readFailed(status) }
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw Failure.readFailed(errSecDecode)
        }
        return key
    }

    /// 真的刪掉 Keychain 那一筆（安全標準一第四條）；本來就沒有也算成功。
    func delete() throws {
        let status = SecItemDelete(Self.query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.deleteFailed(status)
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
