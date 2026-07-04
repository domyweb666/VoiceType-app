import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OpenAI API 金鑰：優先使用 [FlutterSecureStorage]（Android Keystore／iOS Keychain／Windows Credential Manager 等）。
///
/// 若曾用舊版 [SharedPreferences] 儲存，首次讀取會自動遷移並刪除舊值。
class SecureStorageService {
  static const _secureKey = 'openai_api_key_secure_v1';
  /// 舊版明文偏好鍵（遷移後移除）。
  static const _legacyPrefsKey = 'openai_api_key';
  /// BytePlus Seed ASR 金鑰（x-api-key）。
  static const _bytePlusSecureKey = 'byteplus_api_key_secure_v1';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  Future<String?> getApiKey() async {
    // 安全儲存讀取可能拋錯（例如 Windows Credential Manager
    // 在 useBackwardCompatibility:false 下），此時視為「尚無金鑰」，
    // 讓 App 顯示「請輸入金鑰」而非卡住。
    String? v;
    try {
      v = await _secure.read(key: _secureKey);
    } catch (_) {
      return null;
    }
    if (v != null && v.isNotEmpty) return v;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        await _secure.write(key: _secureKey, value: legacy);
      } catch (_) {
        // 遷移寫入失敗時仍回傳舊值，不刪除舊鍵，留待下次再試遷移。
        return legacy;
      }
      await prefs.remove(_legacyPrefsKey);
      return legacy;
    }
    return null;
  }

  Future<void> setApiKey(String key) async {
    // 寫入失敗必須讓使用者知道（否則會誤以為金鑰已存），改拋清楚的例外。
    try {
      await _secure.write(key: _secureKey, value: key);
    } catch (e) {
      throw Exception('無法儲存 API 金鑰到安全儲存區：$e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }

  Future<void> deleteApiKey() async {
    // 刪除失敗同樣需讓使用者知道，避免以為已清除實際仍存在。
    try {
      await _secure.delete(key: _secureKey);
    } catch (e) {
      throw Exception('無法從安全儲存區刪除 API 金鑰：$e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }

  Future<String?> getBytePlusApiKey() async {
    // 讀取失敗視為「尚無金鑰」，讓 UI 走「請輸入金鑰」而非卡住。
    try {
      final v = await _secure.read(key: _bytePlusSecureKey);
      return (v != null && v.isNotEmpty) ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setBytePlusApiKey(String key) async {
    try {
      await _secure.write(key: _bytePlusSecureKey, value: key);
    } catch (e) {
      throw Exception('無法儲存 BytePlus 金鑰到安全儲存區：$e');
    }
  }

  Future<void> deleteBytePlusApiKey() async {
    try {
      await _secure.delete(key: _bytePlusSecureKey);
    } catch (e) {
      throw Exception('無法從安全儲存區刪除 BytePlus 金鑰：$e');
    }
  }
}
