import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../services/secure_storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const _privacyDisclosureKey = 'privacy_disclosure_seen_v1';
  static const _polishPromptKey = 'polish_system_prompt_v1';
  static const _customGlossaryKey = 'custom_glossary_v1';
  static const _textScaleKey = 'ui_text_scale_v1';
  static const _themeModeKey = 'ui_theme_mode_v1';
  static const _asrEngineKey = 'asr_engine_v1';
  static const _autoCopyKey = 'auto_copy_polished_v1';

  /// 設定頁提供的字級選項（與 SegmentedButton 的四個選項一致）。
  /// 舊版本可能存過落在此清單外的原始倍率（例如 0.85／1.35），
  /// 載入時會就近吸附到這幾個值，讓 UI 一定能標示到某個選項。
  static const List<double> textScaleChips = [0.9, 1.0, 1.15, 1.3];

  final SecureStorageService _storage = SecureStorageService();
  String? _apiKey;
  String? _bytePlusApiKey;
  AsrEngine _asrEngine = AsrEngine.openai;
  bool _autoCopyPolished = true;
  bool _hasSeenPrivacyDisclosure = false;
  bool _isLoading = true;
  String _polishSystemPrompt = AppConstants.oralDraftSystemPrompt;
  /// 自訂詞彙（每行一筆，或以逗號／分號分隔）；潤飾與轉錄 prompt 會參考。
  String _customGlossary = '';
  double _uiTextScale = 1.0;
  ThemeMode _themeMode = ThemeMode.system;

  String? get apiKey => _apiKey;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  String? get bytePlusApiKey => _bytePlusApiKey;
  bool get hasBytePlusKey =>
      _bytePlusApiKey != null && _bytePlusApiKey!.isNotEmpty;
  AsrEngine get asrEngine => _asrEngine;

  /// 目前選定的轉錄引擎是否已備妥金鑰（可開始轉錄）。
  /// 潤飾另需 OpenAI 金鑰（見 [hasApiKey]）。
  bool get canTranscribe =>
      _asrEngine == AsrEngine.byteplus ? hasBytePlusKey : hasApiKey;

  /// 轉錄＋潤飾完成後是否自動把文字稿複製到剪貼簿。
  bool get autoCopyPolished => _autoCopyPolished;
  bool get isLoading => _isLoading;
  bool get hasSeenPrivacyDisclosure => _hasSeenPrivacyDisclosure;
  ThemeMode get themeMode => _themeMode;

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
    _bytePlusApiKey = await _storage.getBytePlusApiKey();
    final prefs = await SharedPreferences.getInstance();
    _hasSeenPrivacyDisclosure = prefs.getBool(_privacyDisclosureKey) ?? false;
    _asrEngine = prefs.getString(_asrEngineKey) == 'byteplus'
        ? AsrEngine.byteplus
        : AsrEngine.openai;
    _autoCopyPolished = prefs.getBool(_autoCopyKey) ?? true;
    _polishSystemPrompt =
        prefs.getString(_polishPromptKey) ?? AppConstants.oralDraftSystemPrompt;
    _customGlossary = prefs.getString(_customGlossaryKey) ?? '';
    final scale = prefs.getDouble(_textScaleKey);
    if (scale != null) {
      // 把舊值就近吸附到某個選項；若原值不在選項上，回寫吸附後的值。
      final snapped = _snapToChip(scale.clamp(0.85, 1.35));
      _uiTextScale = snapped;
      if ((snapped - scale).abs() > 0.001) {
        await prefs.setDouble(_textScaleKey, snapped);
      }
    } else {
      _uiTextScale = 1.0;
    }
    final modeStr = prefs.getString(_themeModeKey) ?? 'system';
    _themeMode = modeStr == 'light'
        ? ThemeMode.light
        : modeStr == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;
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

  Future<void> setBytePlusApiKey(String key) async {
    await _storage.setBytePlusApiKey(key);
    _bytePlusApiKey = key;
    notifyListeners();
  }

  Future<void> clearBytePlusApiKey() async {
    await _storage.deleteBytePlusApiKey();
    _bytePlusApiKey = null;
    notifyListeners();
  }

  Future<void> setAsrEngine(AsrEngine engine) async {
    _asrEngine = engine;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _asrEngineKey,
      engine == AsrEngine.byteplus ? 'byteplus' : 'openai',
    );
  }

  Future<void> setAutoCopyPolished(bool value) async {
    _autoCopyPolished = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCopyKey, value);
  }

  Future<void> setPolishSystemPrompt(String text) async {
    // 防呆：存空白等同還原預設，避免之後潤飾拿空的 system prompt 去跑。
    if (text.trim().isEmpty) {
      await resetPolishSystemPromptToDefault();
      return;
    }
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
    // 舊版可能已把空字串存進偏好，這裡再兜底一次。
    final base = _polishSystemPrompt.trim().isEmpty
        ? AppConstants.oralDraftSystemPrompt
        : _polishSystemPrompt;
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

  /// 將任意倍率就近吸附到 [textScaleChips] 之一。
  static double _snapToChip(double scale) {
    var best = textScaleChips.first;
    var bestD = (scale - best).abs();
    for (final c in textScaleChips.skip(1)) {
      final d = (scale - c).abs();
      if (d < bestD) {
        best = c;
        bestD = d;
      }
    }
    return best;
  }

  Future<void> setUiTextScale(double value) async {
    _uiTextScale = value.clamp(0.85, 1.35);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, _uiTextScale);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final modeStr = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString(_themeModeKey, modeStr);
  }

}
