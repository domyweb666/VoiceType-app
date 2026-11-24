import CryptoKit
import Foundation
import Security

/// 方塊 M5：加密歷史檔用的金鑰，只存在 Keychain（安全標準二 🔴）。不給任何人看、不進備份檔。
/// 2026-11-25 米定：跟 iCloud 鑰匙圈走，換新手機用 iCloud 還原才解得開文字稿。
/// 每把金鑰放兩份：本機一份（只在這台，存讀都用它），iCloud 鑰匙圈一份（帶去新手機）。
/// 本機那份一定要留：別台手機按刪除全部資料，鑰匙圈那份會跟著不見，這台的文字稿不能因此解不開。
/// 兩台手機可能各有一把，所以鑰匙圈裡照金鑰自己的指紋分帳號，不互相蓋。
struct TranscriptEncryptionKeyStore {
    enum Failure: Error, Equatable {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
    }

    private static let service = "org.domyweb.misay.transcripts"
    /// 這台存文字稿用的那一把。
    private static let account = "data-key"
    /// 其他打得開這台文字稿的金鑰，與鑰匙圈裡的每一把：後面接指紋。
    private static let sharedAccountPrefix = "data-key."
    private static let fingerprintBytes = 8

    /// 有就讀；沒有先看鑰匙圈有沒有從舊手機帶過來的；都沒有才產生一把 256-bit。
    func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try read() {
            return existing
        }
        let key = try sharedKeys(inICloud: true).first ?? SymmetricKey(size: .bits256)
        try add(key, account: Self.account, inICloud: false)
        backUpToICloud()
        return key
    }

    /// 這台那一把打不開時，其他可能打得開的。讀不到就當沒有：檔案照舊另存不刪，下次再試。
    func otherKeys() -> [SymmetricKey] {
        let local = (try? sharedKeys(inICloud: false)) ?? []
        let cloud = (try? sharedKeys(inICloud: true)) ?? []
        return local + cloud
    }

    /// 用鑰匙圈那把打開了檔：本機也留一份，之後別台刪掉鑰匙圈那份也不怕。
    func keep(_ key: SymmetricKey) {
        do {
            try addUnlessPresent(key, inICloud: false)
        } catch {
            DiagnosticLog.shared.record("文字稿金鑰：本機沒留成 \(error)")
        }
    }

    /// 把這台有的金鑰放進 iCloud 鑰匙圈；已經有的不動。放不進去不影響這台存讀，下次打開再放。
    func backUpToICloud() {
        do {
            guard let primary = try read() else {
                return
            }
            for key in try [primary] + sharedKeys(inICloud: false) {
                try addUnlessPresent(key, inICloud: true)
            }
        } catch {
            DiagnosticLog.shared.record("文字稿金鑰：沒放進 iCloud 鑰匙圈 \(error)")
        }
    }

    /// 刪除全部資料（S2-9）：文字稿都刪了之後才叫，下一次存文字稿會產新的一把。
    /// 鑰匙圈只刪這台那幾把；別台的另一把留著，那是別台的文字稿。
    func delete() throws {
        for key in try [read()].compactMap({ $0 }) + sharedKeys(inICloud: false) {
            try remove(account: Self.sharedAccount(for: key), inICloud: true)
            try remove(account: Self.sharedAccount(for: key), inICloud: false)
        }
        try remove(account: Self.account, inICloud: false)
    }

    /// 只給測試用：本機與鑰匙圈的全部刪掉。真機上刪了等於所有歷史都讀不回來。
    func deleteForTesting() throws {
        try deleteLocalForTesting()
        try deleteICloudForTesting()
    }

    /// 只給測試用：假裝別台手機刪掉了鑰匙圈那幾份。
    func deleteICloudForTesting() throws {
        try deleteAll(inICloud: true)
    }

    /// 只給測試用：假裝換了新手機，只有鑰匙圈帶得過來。
    func deleteLocalForTesting() throws {
        try deleteAll(inICloud: false)
    }

    func addUnlessPresent(_ key: SymmetricKey, inICloud: Bool) throws {
        do {
            try add(key, account: Self.sharedAccount(for: key), inICloud: inICloud)
        } catch Failure.saveFailed(errSecDuplicateItem) {
            return
        }
    }

    private func read() throws -> SymmetricKey? {
        var query = Self.query(inICloud: false)
        query[kSecAttrAccount as String] = Self.account
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

    /// 帳號帶指紋的那幾把，照帳號排，每次順序一樣。內容跟指紋對不上的不用。
    private func sharedKeys(inICloud: Bool) throws -> [SymmetricKey] {
        var query = Self.query(inICloud: inICloud)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            throw Failure.readFailed(status)
        }
        var keys: [String: SymmetricKey] = [:]
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data,
                  account == Self.sharedAccount(for: SymmetricKey(data: data))
            else {
                continue
            }
            keys[account] = SymmetricKey(data: data)
        }
        return keys.sorted { $0.key < $1.key }.map(\.value)
    }

    private func add(_ key: SymmetricKey, account: String, inICloud: Bool) throws {
        var attributes = Self.query(inICloud: inICloud)
        attributes[kSecAttrAccount as String] = account
        attributes[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        attributes[kSecAttrAccessible as String] = inICloud
            ? kSecAttrAccessibleAfterFirstUnlock
            : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw Failure.saveFailed(status)
        }
    }

    private func remove(account: String, inICloud: Bool) throws {
        var query = Self.query(inICloud: inICloud)
        query[kSecAttrAccount as String] = account
        try remove(query)
    }

    private func deleteAll(inICloud: Bool) throws {
        try remove(Self.query(inICloud: inICloud))
    }

    private func remove(_ query: [String: Any]) throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.saveFailed(status)
        }
    }

    /// 指紋是雜湊的前幾個 byte，推不回金鑰。
    private static func sharedAccount(for key: SymmetricKey) -> String {
        let digest = key.withUnsafeBytes { SHA256.hash(data: $0) }
        let hex = digest.prefix(fingerprintBytes).map { String(format: "%02x", $0) }.joined()
        return sharedAccountPrefix + hex
    }

    private static func query(inICloud: Bool) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: inICloud,
        ]
    }
}
