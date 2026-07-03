import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// 提供 Hive 加密所需的 [HiveAesCipher]，金鑰存放於 [FlutterSecureStorage]
/// （Android Keystore／iOS Keychain／Windows Credential Manager 等）。
///
/// 金鑰只產生一次；首次呼叫若無金鑰，會以 [Hive.generateSecureKey] 產生 32 bytes、
/// base64 存入 secure storage，之後每次都讀回同一把金鑰。
class HiveEncryptionService {
  /// secure storage 內的金鑰名稱；版本後綴便於未來輪替。
  static const String _keyName = 'hive_enc_key_v1';

  /// 與 [SecureStorageService] 使用相同選項，確保同一裝置讀寫一致。
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  /// 快取 cipher，重複呼叫不再讀 secure storage。
  static HiveAesCipher? _cached;

  /// 取得（必要時建立）transcripts box 的加密器。
  static Future<HiveAesCipher> cipher() async {
    final cached = _cached;
    if (cached != null) return cached;

    final bytes = await _loadOrCreateKey();
    final c = HiveAesCipher(bytes);
    _cached = c;
    return c;
  }

  /// 讀取既有金鑰；若不存在則產生並寫回。回傳 32 bytes 的原始金鑰。
  static Future<List<int>> _loadOrCreateKey() async {
    String? existing;
    try {
      existing = await _secure.read(key: _keyName);
    } catch (e, st) {
      // 讀取失敗屬於無法復原情境（Keychain／Keystore 異常），明確往上拋。
      debugPrint('HiveEncryptionService 讀取金鑰失敗: $e\n$st');
      throw StateError('無法讀取 Hive 加密金鑰: $e');
    }

    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }

    final key = Hive.generateSecureKey(); // 32 bytes
    try {
      await _secure.write(key: _keyName, value: base64Encode(key));
    } catch (e, st) {
      // 寫入失敗代表金鑰無法持久化，之後將無法解密，屬無法復原情境。
      debugPrint('HiveEncryptionService 寫入金鑰失敗: $e\n$st');
      throw StateError('無法儲存 Hive 加密金鑰: $e');
    }
    return key;
  }
}
