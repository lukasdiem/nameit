import 'package:flutter/material.dart';

/// nameIT brand colours. Violet is the brand, mint the accent (it is also the
/// head in the logo), amber is used sparingly for stars and rewards.
class Brand {
  static const violet = Color(0xFF7C2AD6); // primary
  static const violetDeep = Color(0xFF5A1BA3); // pressed / dark containers
  static const violetLight = Color(0xFFC9A6FF); // primary on dark backgrounds
  static const violetTint = Color(0xFFF1E9FC); // light surfaces
  static const mint = Color(0xFF4FE0B0); // secondary, logo head
  static const mintDark = Color(0xFF0E7A5A); // mint that carries white text
  static const amber = Color(0xFFFFB627); // tertiary, stars and rewards
  static const coral = Color(0xFFE5484D); // wrong answers, streak
  static const ink = Color(0xFF1E1433); // text
}

class AppTheme {
  static const seed = Brand.violet;
  static const good = Brand.mintDark;
  static const bad = Brand.coral;
  static const gold = Brand.amber;

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ColorScheme _scheme(Brightness b) {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    if (b == Brightness.light) {
      return base.copyWith(
        primary: Brand.violet,
        onPrimary: Colors.white,
        primaryContainer: Brand.violetTint,
        onPrimaryContainer: const Color(0xFF3A0E73),
        secondary: Brand.mintDark,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFD3F8EA),
        onSecondaryContainer: const Color(0xFF00382A),
        tertiary: const Color(0xFF8A5A00),
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFFFE7B3),
        onTertiaryContainer: const Color(0xFF3D2600),
        error: Brand.coral,
        surface: const Color(0xFFFCFAFF),
        onSurface: Brand.ink,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF7F2FD),
        surfaceContainer: const Color(0xFFF3EDFB),
        surfaceContainerHigh: const Color(0xFFEEE6F9),
        surfaceContainerHighest: const Color(0xFFE8DFF5),
        outline: const Color(0xFF6E6680),
        outlineVariant: const Color(0xFFDCD3EA),
      );
    }
    return base.copyWith(
      primary: Brand.violetLight,
      onPrimary: const Color(0xFF3A0E73),
      primaryContainer: Brand.violetDeep,
      onPrimaryContainer: Brand.violetTint,
      secondary: Brand.mint,
      onSecondary: const Color(0xFF003828),
      secondaryContainer: const Color(0xFF0B5A43),
      onSecondaryContainer: const Color(0xFFD3F8EA),
      tertiary: Brand.amber,
      onTertiary: const Color(0xFF3D2600),
      tertiaryContainer: const Color(0xFF5C3D00),
      onTertiaryContainer: const Color(0xFFFFE7B3),
      surface: const Color(0xFF14101C),
      onSurface: const Color(0xFFEDE7F6),
      surfaceContainerLowest: const Color(0xFF0F0B16),
      surfaceContainerLow: const Color(0xFF1C1726),
      surfaceContainer: const Color(0xFF211B2C),
      surfaceContainerHigh: const Color(0xFF2B2438),
      surfaceContainerHighest: const Color(0xFF362E44),
      outline: const Color(0xFF9C93AD),
      outlineVariant: const Color(0xFF443B53),
    );
  }

  static ThemeData _base(Brightness b) {
    final scheme = _scheme(b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.outlineVariant,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: b == Brightness.light ? Brand.ink : scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: b == Brightness.light ? Colors.white : scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
