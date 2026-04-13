import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OpenAI API 金鑰：優先使用 [FlutterSecureStorage]（Android Keystore／iOS Keychain／Windows Credential Manager 等）。
///
/// 若曾用舊版 [SharedPreferences] 儲存，首次讀取會自動遷移並刪除舊值。
class SecureStorageService {
  static const _secureKey = 'openai_api_key_secure_v1';
  /// 舊版明文偏好鍵（遷移後移除）。
  static const _legacyPrefsKey = 'openai_api_key';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  Future<String?> getApiKey() async {
    final v = await _secure.read(key: _secureKey);
    if (v != null && v.isNotEmpty) return v;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(key: _secureKey, value: legacy);
      await prefs.remove(_legacyPrefsKey);
      return legacy;
    }
    return null;
  }

  Future<void> setApiKey(String key) async {
    await _secure.write(key: _secureKey, value: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }

  Future<void> deleteApiKey() async {
    await _secure.delete(key: _secureKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }
}
