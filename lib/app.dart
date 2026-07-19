import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

class VoiceTypeApp extends StatelessWidget {
  const VoiceTypeApp({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    // 只訂閱真正影響 MaterialApp 的兩個值：主題模式與字級倍率。
    // 其餘設定變更（例如「已看過隱私說明」旗標）不該重建整個 MaterialApp，
    // 否則會在對話框互動的 await 空檔把 Navigator／對話框連根重建，導致關不掉。
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (s) => s.themeMode,
    );
    final textScale = context.select<SettingsProvider, double>(
      (s) => s.uiTextScale,
    );
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'VoiceType',
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child ??
              ColoredBox(
                color: AppTokens.dark.bg,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
