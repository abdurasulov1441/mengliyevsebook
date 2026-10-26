import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens of the app: warm "paper" surfaces, ink text and the brand
/// green of the MB logo. Interface text is Inter; book titles use Literata
/// (with Lora as fallback for glyphs Literata lacks, e.g. Uzbek Cyrillic Ҳ).
abstract final class AppPalette {
  static const brand = Color(0xFF0D7C66);
  static const brandDark = Color(0xFF09594A);
  static const brandSoft = Color(0xFFE2F0EB);

  static const background = Color(0xFFF7F4EE);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEFEAE1);

  static const ink = Color(0xFF1D1B18);
  static const inkSoft = Color(0xFF59544C);
  static const muted = Color(0xFF9A9389);
  static const line = Color(0xFFE6E0D5);

  static const gold = Color(0xFFC08A2E);
  static const goldSoft = Color(0xFFF7ECD8);
  static const danger = Color(0xFFC2410C);
  static const success = Color(0xFF2F8A4C);

  /// Generated covers when a book has no picture.
  static const coverGradients = [
    [Color(0xFF0D7C66), Color(0xFF0A4F42)],
    [Color(0xFF7B4A2A), Color(0xFF4A2A16)],
    [Color(0xFF2F4B6E), Color(0xFF1B2D45)],
    [Color(0xFF6B2F45), Color(0xFF41192A)],
    [Color(0xFF4A3F6B), Color(0xFF2B2442)],
    [Color(0xFF8A6A1F), Color(0xFF574210)],
    [Color(0xFF1F6F8B), Color(0xFF123F50)],
    [Color(0xFF5B6B2E), Color(0xFF34401A)],
  ];
}

abstract final class AppFonts {
  static const ui = 'Inter';
  static const book = 'Literata';
  static const fallback = ['Lora'];
}

abstract final class AppText {
  static const _ink = AppPalette.ink;

  static const display = TextStyle(fontFamily: AppFonts.book, fontFamilyFallback: AppFonts.fallback, fontSize: 28, height: 1.15, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.3);
  static const title = TextStyle(fontFamily: AppFonts.book, fontFamilyFallback: AppFonts.fallback, fontSize: 21, height: 1.2, fontWeight: FontWeight.w700, color: _ink);
  static const bookTitle = TextStyle(fontFamily: AppFonts.book, fontFamilyFallback: AppFonts.fallback, fontSize: 15, height: 1.25, fontWeight: FontWeight.w600, color: _ink);
  static const section = TextStyle(fontFamily: AppFonts.ui, fontSize: 17, height: 1.3, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.2);
  static const body = TextStyle(fontFamily: AppFonts.ui, fontSize: 15, height: 1.45, fontWeight: FontWeight.w400, color: _ink);
  static const bodySoft = TextStyle(fontFamily: AppFonts.ui, fontSize: 14, height: 1.45, fontWeight: FontWeight.w400, color: AppPalette.inkSoft);
  static const label = TextStyle(fontFamily: AppFonts.ui, fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, color: _ink);
  static const caption = TextStyle(fontFamily: AppFonts.ui, fontSize: 12, height: 1.3, fontWeight: FontWeight.w500, color: AppPalette.muted);
  static const overline = TextStyle(fontFamily: AppFonts.ui, fontSize: 11, height: 1.2, fontWeight: FontWeight.w700, color: AppPalette.brand, letterSpacing: 1.1);
}

abstract final class AppTheme {
  static const radius = 16.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.brand,
      primary: AppPalette.brand,
      surface: AppPalette.surface,
      brightness: Brightness.light,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: AppFonts.ui);
    return base.copyWith(
      scaffoldBackgroundColor: AppPalette.background,
      textTheme: base.textTheme.apply(fontFamily: AppFonts.ui, bodyColor: AppPalette.ink, displayColor: AppPalette.ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.section,
        systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: AppFonts.ui, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.ink,
          minimumSize: const Size(64, 52),
          side: const BorderSide(color: AppPalette.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: AppFonts.ui, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.brand, textStyle: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        hintStyle: AppText.bodySoft.copyWith(color: AppPalette.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppPalette.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppPalette.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppPalette.brand, width: 1.5)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: AppText.title,
        contentTextStyle: AppText.bodySoft,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.ink,
        contentTextStyle: AppText.body.copyWith(color: Colors.white),
        actionTextColor: const Color(0xFF7FD8C2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppPalette.brand, linearTrackColor: AppPalette.surfaceAlt),
      dividerTheme: const DividerThemeData(color: AppPalette.line, thickness: 1, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
