import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Quiet, warm palette: cream canvas, near-black ink, hairline dividers and a
/// single clay accent that is used sparingly (main action, translation).
abstract final class AppColors {
  static const background = Color(0xFFF5F4ED);
  static const ink = Color(0xFF1F1E1D);
  static const inkSecondary = Color(0xFF75726A);
  static const inkMuted = Color(0xFFA19E94);
  static const hairline = Color(0xFFE2DFD3);
  static const outline = Color(0xFFCFCBBE);
  static const clay = Color(0xFFC96442);
  static const danger = Color(0xFF9B2C1F);
  static const dangerTint = Color(0xFFF1D9D3);
}

/// New York on iOS; Georgia (present on iOS/macOS) if that name isn't found.
const _serifFont = '.AppleSystemUIFontSerif';
const _serifFallback = ['Georgia', 'Times New Roman', 'serif'];

/// The serif "voice" used for titles and the word being studied.
TextStyle serifStyle({
  required double fontSize,
  Color color = AppColors.ink,
  FontStyle? fontStyle,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _serifFont,
    fontFamilyFallback: _serifFallback,
    fontSize: fontSize,
    color: color,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    fontWeight: FontWeight.w400,
  );
}

/// Full-width rounded main action (scan, done, back to decks).
final ButtonStyle pillButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  shape: const StadiumBorder(),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
);

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.clay,
    onPrimary: Colors.white,
    surface: AppColors.background,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkSecondary,
    outline: AppColors.outline,
    outlineVariant: AppColors.hairline,
    error: AppColors.danger,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    // iOS has no ink ripple; keep taps quiet.
    splashFactory: NoSplash.splashFactory,
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 0.5,
      space: 0.5,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: serifStyle(fontSize: 20),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    // Swipe-back and slide transitions like iOS on every platform.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
      primaryColor: AppColors.clay,
    ),
  );
}
