import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VoiceType design tokens — bold-editor look.
class AppTokens {
  final Color bg;
  final Color bgElev;
  final Color bgCard;
  final Color bgChip;
  final Color line;
  final Color lineStrong;
  final Color fg;
  final Color fgDim;
  final Color fgMute;
  final Color accent;
  final Color accentInk;
  final Color accentGlow;
  final Color danger;
  final Color dangerGlow;
  final Color ok;
  final Brightness brightness;

  static const double radiusLg = 20;
  static const double radiusMd = 14;
  static const double radiusSm = 10;

  const AppTokens({
    required this.bg,
    required this.bgElev,
    required this.bgCard,
    required this.bgChip,
    required this.line,
    required this.lineStrong,
    required this.fg,
    required this.fgDim,
    required this.fgMute,
    required this.accent,
    required this.accentInk,
    required this.accentGlow,
    required this.danger,
    required this.dangerGlow,
    required this.ok,
    required this.brightness,
  });

  static const dark = AppTokens(
    bg: Color(0xFF0B0F10),
    bgElev: Color(0xFF11161A),
    bgCard: Color(0xFF161C21),
    bgChip: Color(0x0AFFFFFF),
    line: Color(0x14FFFFFF),
    lineStrong: Color(0x24FFFFFF),
    fg: Color(0xFFE9EEF0),
    fgDim: Color(0xFF9AA5AD),
    fgMute: Color(0xFF5C6870),
    accent: Color(0xFF2DD4BF),
    accentInk: Color(0xFF042420),
    accentGlow: Color(0x592DD4BF),
    danger: Color(0xFFF87171),
    dangerGlow: Color(0x59F87171),
    ok: Color(0xFF7DE2A5),
    brightness: Brightness.dark,
  );

  static const light = AppTokens(
    bg: Color(0xFFF6F5F1),
    bgElev: Color(0xFFFFFFFF),
    bgCard: Color(0xFFFFFFFF),
    bgChip: Color(0x0A000000),
    line: Color(0x14000000),
    lineStrong: Color(0x24000000),
    fg: Color(0xFF1A1D1E),
    fgDim: Color(0xFF5A6066),
    fgMute: Color(0xFF9AA0A6),
    accent: Color(0xFF0F766E),
    accentInk: Color(0xFFFFFFFF),
    accentGlow: Color(0x400F766E),
    danger: Color(0xFFDC2626),
    dangerGlow: Color(0x40DC2626),
    ok: Color(0xFF15803D),
    brightness: Brightness.light,
  );
}

class AppThemeExt extends ThemeExtension<AppThemeExt> {
  final AppTokens tokens;
  const AppThemeExt(this.tokens);

  @override
  AppThemeExt copyWith({AppTokens? tokens}) =>
      AppThemeExt(tokens ?? this.tokens);

  @override
  AppThemeExt lerp(ThemeExtension<AppThemeExt>? other, double t) {
    if (other is! AppThemeExt) return this;
    return t < 0.5 ? this : other;
  }
}

/// Helper: bold gothic heading (Noto Sans TC w700).
TextStyle serifItalic({
  required double size,
  Color? color,
  FontWeight weight = FontWeight.w700,
  double? height,
  double letterSpacing = -0.015,
}) {
  return GoogleFonts.notoSansTc(
    fontSize: size,
    fontStyle: FontStyle.normal,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing * size,
  );
}

/// Helper: JetBrains Mono for tabular numbers / kbd / small meta.
TextStyle mono({
  required double size,
  Color? color,
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0.02,
  double? height,
}) {
  return GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

ThemeData buildTheme(AppTokens t) {
  final scheme = ColorScheme(
    brightness: t.brightness,
    primary: t.accent,
    onPrimary: t.accentInk,
    primaryContainer: Color.alphaBlend(t.accent.withValues(alpha: 0.18), t.bgCard),
    onPrimaryContainer: t.fg,
    secondary: t.accent,
    onSecondary: t.accentInk,
    secondaryContainer: t.bgChip,
    onSecondaryContainer: t.fg,
    error: t.danger,
    onError: t.brightness == Brightness.dark
        ? const Color(0xFF2A0808)
        : const Color(0xFFFFFFFF),
    errorContainer: Color.alphaBlend(t.danger.withValues(alpha: 0.18), t.bgCard),
    onErrorContainer: t.fg,
    surface: t.bg,
    onSurface: t.fg,
    surfaceContainerLowest: t.bg,
    surfaceContainerLow: t.bgElev,
    surfaceContainer: t.bgCard,
    surfaceContainerHigh: t.bgCard,
    surfaceContainerHighest: t.bgElev,
    onSurfaceVariant: t.fgDim,
    outline: t.lineStrong,
    outlineVariant: t.line,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: t.fg,
    onInverseSurface: t.bg,
    inversePrimary: t.accent,
  );

  final base = GoogleFonts.notoSansTcTextTheme(
    t.brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    textTheme: base.apply(bodyColor: t.fg, displayColor: t.fg),
    extensions: [AppThemeExt(t)],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: t.bg,
      foregroundColor: t.fg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.notoSansTc(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: t.fg,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(color: t.line, width: 1),
      ),
      color: t.bgCard,
    ),
    dialogTheme: DialogThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      backgroundColor: t.bgElev,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: t.bgElev,
      contentTextStyle: TextStyle(color: t.fg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(color: t.lineStrong),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.accent,
      linearTrackColor: t.bgChip,
    ),
    dividerColor: t.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.bgChip,
      hintStyle: TextStyle(color: t.fgMute),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: BorderSide(color: t.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: BorderSide(color: t.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: BorderSide(color: t.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: t.accent,
        foregroundColor: t.accentInk,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.fg,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        side: BorderSide(color: t.lineStrong),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.fgDim,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: t.fgDim),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      iconColor: t.fgDim,
      textColor: t.fg,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.bgChip,
      selectedColor: t.accent,
      labelStyle: TextStyle(color: t.fgDim, fontSize: 12.5),
      secondaryLabelStyle: TextStyle(color: t.accentInk, fontSize: 12.5),
      side: BorderSide(color: t.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      labelColor: t.fg,
      unselectedLabelColor: t.fgDim,
    ),
  );
}

ThemeData lightTheme() => buildTheme(AppTokens.light);
ThemeData darkTheme() => buildTheme(AppTokens.dark);

extension AppThemeContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppThemeExt>()?.tokens ?? AppTokens.dark;
}
