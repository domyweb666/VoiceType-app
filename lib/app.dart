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
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'VoiceType',
          debugShowCheckedModeBanner: false,
          theme: lightTheme(),
          darkTheme: darkTheme(),
          themeMode: settings.themeMode,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.uiTextScale),
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
      },
    );
  }
}
