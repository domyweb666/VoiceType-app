import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/user_disclosure.dart';
import '../providers/settings_provider.dart';
import '../services/cost_estimate_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
    await context.read<SettingsProvider>().setPolishSystemPrompt(
          _polishController.text,
        );
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
    await context.read<SettingsProvider>().setCustomGlossary(
          _glossaryController.text,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存自訂詞彙')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    if (!settings.isLoading && !_seededFromProvider) {
      _seededFromProvider = true;
      _apiKeyController.text = settings.apiKey ?? '';
      _polishController.text = settings.polishSystemPrompt;
      _glossaryController.text = settings.customGlossary;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: settings.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          UserDisclosure.privacyAndCostTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        UserDisclosure.privacyAndCostBody,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.45,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '費用粗估（新台幣）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        SessionCostEstimateService.buildSettingsEstimateText(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.45,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '文字稿潤飾提示詞',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '以下內容會作為潤飾 API 的 system 提示詞：規則與 App 預設一致（最小化干預、刪贅字、斷句、標點、臺灣繁體、禁止標題與小標）。'
                    '修改後無須重新編譯即可生效。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.45,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '自訂詞彙',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '每行一個詞或片語，亦可用逗號、分號分隔。會併入轉錄與潤飾請求：轉錄時作為專有名詞提示，潤飾時請模型盡量維持您指定的寫法。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.45,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
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
                  FilledButton(
                    onPressed: _saveGlossary,
                    child: const Text('儲存自訂詞彙'),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.accessibility_new_rounded,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '顯示與可及性',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '調整全 App 字級與對比，方便長時間閱讀逐字稿（桌面版首頁可用空白鍵切換錄音，見首頁說明）。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.45,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '介面字級',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<double>(
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
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.key_rounded,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'OpenAI API Key',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                        ),
                        onPressed: () {
                          setState(() => _obscureText = !_obscureText);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final key = _apiKeyController.text.trim();
                      if (key.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('請輸入 API 金鑰')),
                        );
                        return;
                      }
                      await context.read<SettingsProvider>().setApiKey(key);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已儲存 API 金鑰')),
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('儲存金鑰'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'API 金鑰由 flutter_secure_storage 儲存（Android Keystore／iOS Keychain／Windows 認證管理員 等，依平台而異），僅用於呼叫 OpenAI。'
                    '若曾使用舊版明文偏好設定，首次啟動會自動遷移至安全儲存。請勿在共用裝置上儲存正式金鑰。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}
