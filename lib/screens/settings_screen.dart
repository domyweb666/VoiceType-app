import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/user_disclosure.dart';
import '../providers/settings_provider.dart';
import '../services/cost_estimate_service.dart';


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
  final _polishController = TextEditingController();
  final _glossaryController = TextEditingController();
  bool _obscureText = true;
  bool _seededFromProvider = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _polishController.dispose();
    _glossaryController.dispose();
    super.dispose();
  }

  Future<void> _savePolishPrompt() async {
    await context
        .read<SettingsProvider>()
        .setPolishSystemPrompt(_polishController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存潤飾提示詞')),
      );
    }
  }

  Future<void> _resetPolishPrompt() async {
    await context.read<SettingsProvider>().resetPolishSystemPromptToDefault();
    if (!mounted) return;
    _polishController.text =
        context.read<SettingsProvider>().polishSystemPrompt;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已還原為 App 預設提示詞')),
    );
  }

  Future<void> _saveGlossary() async {
    await context
        .read<SettingsProvider>()
        .setCustomGlossary(_glossaryController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存自訂詞彙')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final t = context.tokens;

    if (!settings.isLoading && !_seededFromProvider) {
      _seededFromProvider = true;
      _apiKeyController.text = settings.apiKey ?? '';
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

                    // Section: 隱私與費用
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

                    // Section: 潤飾提示詞
                    _Section(
                      title: '文字稿潤飾提示詞',
                      desc:
                          '會作為潤飾 API 的 system 提示詞：規則與 App 預設一致（最小化干預、刪贅字、斷句、標點、臺灣繁體、禁止標題與小標）。',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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

                    // Section: 自訂詞彙
                    _Section(
                      title: '自訂詞彙',
                      desc:
                          '每行一個詞或片語。會併入轉錄與潤飾請求：轉錄時作為專有名詞提示，潤飾時請模型盡量維持您指定的寫法。',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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

                    // Section: API Key
                    _Section(
                      title: 'OpenAI API Key',
                      desc:
                          'API 金鑰由 flutter_secure_storage 儲存（Android Keystore／iOS Keychain／Windows 認證管理員），僅用於呼叫 OpenAI。請勿在共用裝置上儲存正式金鑰。',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _apiKeyController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              hintText: 'sk-...',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() => _obscureText = !_obscureText);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton(
                              onPressed: () async {
                                final key = _apiKeyController.text.trim();
                                if (key.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('請輸入 API 金鑰')),
                                  );
                                  return;
                                }
                                await context
                                    .read<SettingsProvider>()
                                    .setApiKey(key);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已儲存 API 金鑰')),
                                  );
                                }
                              },
                              child: const Text('儲存金鑰'),
                            ),
                          ),
                        ],
                      ),
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
