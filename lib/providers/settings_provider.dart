import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../services/secure_storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const _privacyDisclosureKey = 'privacy_disclosure_seen_v1';
  static const _polishPromptKey = 'polish_system_prompt_v1';
  static const _customGlossaryKey = 'custom_glossary_v1';
  static const _textScaleKey = 'ui_text_scale_v1';

  final SecureStorageService _storage = SecureStorageService();
  String? _apiKey;
  bool _hasSeenPrivacyDisclosure = false;
  bool _isLoading = true;
  String _polishSystemPrompt = AppConstants.oralDraftSystemPrompt;
  /// 自訂詞彙（每行一筆，或以逗號／分號分隔）；潤飾與轉錄 prompt 會參考。
  String _customGlossary = '';
  double _uiTextScale = 1.0;

  String? get apiKey => _apiKey;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  bool get isLoading => _isLoading;
  bool get hasSeenPrivacyDisclosure => _hasSeenPrivacyDisclosure;

  /// 文字稿潤飾用 system 提示詞（可於設定頁編輯；預設與 [AppConstants.oralDraftSystemPrompt] 相同）。
  String get polishSystemPrompt => _polishSystemPrompt;

  /// 介面字級倍率（約 0.85～1.35）。
  double get uiTextScale => _uiTextScale;

  /// 設定頁編輯的原始字串。
  String get customGlossary => _customGlossary;

  SettingsProvider() {
    _loadAll();
  }

  Future<void> _loadAll() async {
    _apiKey = await _storage.getApiKey();
    final prefs = await SharedPreferences.getInstance();
    _hasSeenPrivacyDisclosure = prefs.getBool(_privacyDisclosureKey) ?? false;
    _polishSystemPrompt =
        prefs.getString(_polishPromptKey) ?? AppConstants.oralDraftSystemPrompt;
    _customGlossary = prefs.getString(_customGlossaryKey) ?? '';
    final scale = prefs.getDouble(_textScaleKey);
    _uiTextScale = scale != null ? scale.clamp(0.85, 1.35) : 1.0;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    await _storage.setApiKey(key);
    _apiKey = key;
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    await _storage.deleteApiKey();
    _apiKey = null;
    notifyListeners();
  }

  Future<void> setPolishSystemPrompt(String text) async {
    _polishSystemPrompt = text;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_polishPromptKey, text);
  }

  Future<void> resetPolishSystemPromptToDefault() async {
    _polishSystemPrompt = AppConstants.oralDraftSystemPrompt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_polishPromptKey);
  }

  /// 解析後的詞條（空白行與重複已略過）。
  List<String> get customGlossaryTerms {
    final re = RegExp(r'[\n,，;；]+');
    return _customGlossary
        .split(re)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> setCustomGlossary(String text) async {
    _customGlossary = text;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customGlossaryKey, text);
  }

  /// 潤飾 API 用：在 system 提示詞末附加自訂詞彙說明。
  String buildOrganizeSystemPrompt() {
    final base = _polishSystemPrompt;
    final terms = customGlossaryTerms;
    if (terms.isEmpty) return base;
    final block = terms.map((e) => '- $e').join('\n');
    return '$base\n\n【使用者自訂詞彙】\n'
        '潤飾輸出請盡量在語境相符時採用下列寫法，勿任意改寫為其他同義詞：\n'
        '$block';
  }

  /// 轉錄 API `prompt` 用：精簡一行，受字數上限由呼叫端裁剪。
  String buildWhisperVocabularyHintLine() {
    final terms = customGlossaryTerms;
    if (terms.isEmpty) return '';
    return terms.take(16).join('、');
  }

  Future<void> markPrivacyDisclosureSeen() async {
    _hasSeenPrivacyDisclosure = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyDisclosureKey, true);
  }

  Future<void> setUiTextScale(double value) async {
    _uiTextScale = value.clamp(0.85, 1.35);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, _uiTextScale);
  }

}
