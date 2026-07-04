import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../config/constants.dart';
import '../config/user_disclosure.dart';
import '../providers/settings_provider.dart';
import '../services/byteplus_asr_service.dart';
import '../services/cost_estimate_service.dart';
import '../services/openai_service.dart';


/// 費用粗估區塊的顯示幣別與匯率標示。
///
/// 這只是「App 端的粗估」，並非即時匯率：實際金額以 OpenAI 帳單為準，
/// 當模型定價或匯率變動時，此處與 [SessionCostEstimateService] 的常數都會失準，
/// 需一併手動更新。此處只負責 UI 標籤，實際換算數字仍取自估算服務。
const String kCostEstimateCurrencyLabel = '新台幣';

/// 匯率假設（1 美元約等於多少 [kCostEstimateCurrencyLabel]）；僅供標示，
/// 真正參與換算的是 [SessionCostEstimateService.twdPerUsd]，兩者須同步。
const double kCostEstimateAssumedFxRate =
    SessionCostEstimateService.twdPerUsd;

class SettingsScreen extends StatefulWidget {
  /// 嵌入在 HomeScreen 的桌面三欄佈局時為 true。
  final bool embedded;
  final VoidCallback? onBack;

  const SettingsScreen({super.key, this.embedded = false, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

double _nearestTextScaleChip(double scale) {
  const choices = [0.9, 1.0, 1.15, 1.3];
  var best = choices.first;
  var bestD = (scale - best).abs();
  for (final c in choices.skip(1)) {
    final d = (scale - c).abs();
    if (d < bestD) {
      best = c;
      bestD = d;
    }
  }
  return best;
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _bytePlusKeyController = TextEditingController();
  final _polishController = TextEditingController();
  final _glossaryController = TextEditingController();
  bool _obscureOpenAI = true;
  bool _obscureBytePlus = true;
  bool _testingOpenAI = false;
  bool _testingBytePlus = false;
  bool _seededFromProvider = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _bytePlusKeyController.dispose();
    _polishController.dispose();
    _glossaryController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 儲存並驗證 OpenAI 金鑰：先存（離線也不擋），再打免費的 /models 驗證。
  Future<void> _saveAndTestOpenAIKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _snack('請先貼上 OpenAI API 金鑰');
      return;
    }
    setState(() => _testingOpenAI = true);
    try {
      await context.read<SettingsProvider>().setApiKey(key);
      try {
        await OpenAIService.verifyApiKey(key);
        _snack('OpenAI 金鑰有效，已儲存 ✓');
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        _snack(code == 401 || code == 403
            ? '金鑰已儲存，但 OpenAI 回報無效（HTTP $code），請確認有沒有貼錯。'
            : '金鑰已儲存，但目前無法驗證（網路問題？），稍後轉錄時會再試。');
      }
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _testingOpenAI = false);
    }
  }

  /// 儲存並驗證 BytePlus 金鑰：提交 0.2 秒靜音檔，submit 被接受即有效。
  Future<void> _saveAndTestBytePlusKey() async {
    final key = _bytePlusKeyController.text.trim();
    if (key.isEmpty) {
      _snack('請先貼上 BytePlus API 金鑰');
      return;
    }
    setState(() => _testingBytePlus = true);
    try {
      await context.read<SettingsProvider>().setBytePlusApiKey(key);
      try {
        await BytePlusAsrService(apiKey: key).verifyKey();
        _snack('BytePlus 金鑰有效，已儲存 ✓');
      } on BytePlusAsrException catch (e) {
        _snack('金鑰已儲存，但驗證失敗：${e.message}');
      } on DioException {
        _snack('金鑰已儲存，但目前無法驗證（網路問題？），稍後轉錄時會再試。');
      }
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _testingBytePlus = false);
    }
  }

  Future<void> _savePolishPrompt() async {
    final settings = context.read<SettingsProvider>();
    final wasEmpty = _polishController.text.trim().isEmpty;
    await settings.setPolishSystemPrompt(_polishController.text);
    if (!mounted) return;
    if (wasEmpty) {
      // 空白視為還原預設（防呆），把還原後的內容帶回輸入框。
      _polishController.text = settings.polishSystemPrompt;
      setState(() {});
      _snack('提示詞不能是空的，已還原為 App 預設');
      return;
    }
    _snack('已儲存潤飾提示詞');
  }

  Future<void> _resetPolishPrompt() async {
    await context.read<SettingsProvider>().resetPolishSystemPromptToDefault();
    if (!mounted) return;
    _polishController.text =
        context.read<SettingsProvider>().polishSystemPrompt;
    setState(() {});
    _snack('已還原為 App 預設提示詞');
  }

  Future<void> _saveGlossary() async {
    await context
        .read<SettingsProvider>()
        .setCustomGlossary(_glossaryController.text);
    if (mounted) {
      _snack('已儲存自訂詞彙');
    }
  }

  static void _openHelpUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _keyField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            size: 18,
          ),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }

  Widget _buildEngineAndKeys(SettingsProvider settings) {
    final t = context.tokens;
    final isBytePlus = settings.asrEngine == AsrEngine.byteplus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<AsrEngine>(
          segments: const [
            ButtonSegment(
              value: AsrEngine.openai,
              label: Text('OpenAI Whisper'),
            ),
            ButtonSegment(
              value: AsrEngine.byteplus,
              label: Text('BytePlus（中文較準）'),
            ),
          ],
          selected: {settings.asrEngine},
          onSelectionChanged: (s) {
            context.read<SettingsProvider>().setAsrEngine(s.first);
          },
        ),
        const SizedBox(height: 10),
        Text(
          isBytePlus
              ? 'BytePlus Seed ASR（字節跳動海外站）中文辨識較準。需要 BytePlus 的 API 金鑰；'
                  '轉錄結果可能是簡體，潤飾階段會統一轉成臺灣繁體（潤飾需要 OpenAI 金鑰）。'
              : '轉錄與潤飾都用同一把 OpenAI 金鑰，設定一把就能用。',
          style: TextStyle(fontSize: 13, color: t.fgDim, height: 1.6),
        ),
        const SizedBox(height: 20),

        // OpenAI 金鑰（潤飾一定用得到，永遠顯示）
        Text(
          isBytePlus ? 'OpenAI API Key（潤飾用）' : 'OpenAI API Key',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: t.fg,
          ),
        ),
        const SizedBox(height: 10),
        _keyField(
          controller: _apiKeyController,
          obscure: _obscureOpenAI,
          onToggleObscure: () =>
              setState(() => _obscureOpenAI = !_obscureOpenAI),
          hint: 'sk-...',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _testingOpenAI ? null : _saveAndTestOpenAIKey,
              icon: _testingOpenAI
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 16),
              label: Text(_testingOpenAI ? '驗證中…' : '儲存並測試'),
            ),
            TextButton.icon(
              onPressed: () => _openHelpUrl(AppConstants.openaiKeyHelpUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('如何取得金鑰？'),
            ),
          ],
        ),

        if (isBytePlus) ...[
          const SizedBox(height: 24),
          Text(
            'BytePlus API Key（轉錄用）',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: t.fg,
            ),
          ),
          const SizedBox(height: 10),
          _keyField(
            controller: _bytePlusKeyController,
            obscure: _obscureBytePlus,
            onToggleObscure: () =>
                setState(() => _obscureBytePlus = !_obscureBytePlus),
            hint: 'BytePlus x-api-key',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _testingBytePlus ? null : _saveAndTestBytePlusKey,
                icon: _testingBytePlus
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 16),
                label: Text(_testingBytePlus ? '驗證中…' : '儲存並測試'),
              ),
              TextButton.icon(
                onPressed: () => _openHelpUrl(AppConstants.bytePlusKeyHelpUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('如何取得金鑰？'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final t = context.tokens;

    if (!settings.isLoading && !_seededFromProvider) {
      _seededFromProvider = true;
      _apiKeyController.text = settings.apiKey ?? '';
      _bytePlusKeyController.text = settings.bytePlusApiKey ?? '';
      _polishController.text = settings.polishSystemPrompt;
      _glossaryController.text = settings.customGlossary;
    }

    final body = settings.isLoading
        ? Center(child: CircularProgressIndicator(color: t.accent))
        : SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              widget.embedded ? 48 : 24,
              24,
              widget.embedded ? 48 : 24,
              140,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero
                    Builder(builder: (heroCtx) {
                      final canPop = Navigator.canPop(heroCtx);
                      final showBack = widget.onBack != null || canPop;
                      return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (showBack) ...[
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onBack ??
                                  () => Navigator.of(heroCtx).maybePop(),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: t.bgChip,
                                  border: Border.all(color: t.line),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(Icons.arrow_back_rounded,
                                    size: 18, color: t.fg),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Text('設定',
                              style: serifItalic(size: 48, color: t.fg, height: 1)),
                        ),
                      ],
                    );
                    }),
                    const SizedBox(height: 30),

                    // Section: 轉錄引擎與金鑰（最常用，放最上面）
                    _Section(
                      title: '轉錄引擎與金鑰',
                      desc: '金鑰只存在這台裝置的系統安全儲存區'
                          '（Windows 認證管理員／iOS Keychain／Android Keystore），'
                          '僅用於呼叫對應服務。請勿在共用裝置上儲存正式金鑰。',
                      child: _buildEngineAndKeys(settings),
                    ),

                    // Section: 完成後動作
                    _Section(
                      title: '完成後動作',
                      desc: null,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('完成後自動複製文字稿'),
                        subtitle: const Text(
                          '轉錄潤飾一結束就把文字稿放進剪貼簿，切過去直接貼上。',
                        ),
                        value: settings.autoCopyPolished,
                        onChanged: (v) => context
                            .read<SettingsProvider>()
                            .setAutoCopyPolished(v),
                      ),
                    ),

                    // Section: 顯示與可及性
                    _Section(
                      title: '顯示與可及性',
                      desc: '調整全 App 字級，方便長時間閱讀逐字稿。',
                      child: SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 0.9, label: Text('較小')),
                          ButtonSegment(value: 1.0, label: Text('預設')),
                          ButtonSegment(value: 1.15, label: Text('較大')),
                          ButtonSegment(value: 1.3, label: Text('特大')),
                        ],
                        selected: {
                          _nearestTextScaleChip(settings.uiTextScale),
                        },
                        onSelectionChanged: (s) {
                          context
                              .read<SettingsProvider>()
                              .setUiTextScale(s.first);
                        },
                      ),
                    ),

                    // Section: 背景主題
                    _Section(
                      title: '背景主題',
                      desc: '選擇介面配色風格。',
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                              value: ThemeMode.system, label: Text('跟隨系統')),
                          ButtonSegment(
                              value: ThemeMode.light, label: Text('淺色')),
                          ButtonSegment(
                              value: ThemeMode.dark, label: Text('暗色')),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (s) {
                          context
                              .read<SettingsProvider>()
                              .setThemeMode(s.first);
                        },
                      ),
                    ),

                    // Section: 進階（一般使用者不需要碰，預設收合）
                    Padding(
                      padding: const EdgeInsets.only(bottom: 36),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(top: 8),
                          title: Text('進階設定',
                              style: serifItalic(size: 26, color: t.fg)),
                          subtitle: Text(
                            '潤飾提示詞與自訂詞彙。預設就能用，想微調 AI 行為再打開。',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: t.fgDim,
                              height: 1.6,
                            ),
                          ),
                          children: [
                            _Section(
                              title: '文字稿潤飾提示詞',
                              desc:
                                  '會作為潤飾 API 的 system 提示詞：規則與 App 預設一致（最小化干預、刪贅字、斷句、標點、臺灣繁體、禁止標題與小標）。',
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _polishController,
                                    maxLines: 14,
                                    minLines: 8,
                                    decoration: const InputDecoration(
                                      alignLabelWithHint: true,
                                      hintText: '潤飾用 system 提示詞…',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton(
                                        onPressed: _savePolishPrompt,
                                        child: const Text('儲存潤飾提示詞'),
                                      ),
                                      OutlinedButton(
                                        onPressed: _resetPolishPrompt,
                                        child: const Text('還原預設'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _Section(
                              title: '自訂詞彙',
                              desc:
                                  '每行一個詞或片語。會併入轉錄與潤飾請求：轉錄時作為專有名詞提示（限 OpenAI 引擎），潤飾時請模型盡量維持您指定的寫法。',
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _glossaryController,
                                    maxLines: 8,
                                    minLines: 4,
                                    decoration: const InputDecoration(
                                      hintText: '例如：\n臺積電\nTSMC\nVoiceType',
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton(
                                      onPressed: _saveGlossary,
                                      child: const Text('儲存自訂詞彙'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Section: 隱私與費用（說明文字，放最後）
                    _Section(
                      title: '隱私與費用',
                      desc: UserDisclosure.privacyAndCostBody,
                      child: const SizedBox.shrink(),
                    ),

                    _Section(
                      title: '費用粗估（$kCostEstimateCurrencyLabel）',
                      desc: SessionCostEstimateService.buildSettingsEstimateText(),
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );

    if (widget.embedded) {
      return Container(color: t.bg, child: body);
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: body),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? desc;
  final Widget child;

  const _Section({required this.title, this.desc, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: serifItalic(size: 26, color: t.fg)),
          if (desc != null) ...[
            const SizedBox(height: 6),
            Text(
              desc!,
              style: TextStyle(
                fontSize: 13.5,
                color: t.fgDim,
                height: 1.6,
              ),
            ),
          ],
          if (child is! SizedBox) ...[
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }
}
