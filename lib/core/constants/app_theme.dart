import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ─── Brand Colors (Ola/Uber inspired) ───────────────────────────────────────
  static const Color primary = Color(0xFF000000);       // pure black (Uber style)
  static const Color primaryLight = Color(0xFF1A1A1A);
  static const Color primaryBlack = Color(0xFF000000);
  static const Color accent = Color(0xFF00C853);        // green accent (Ola style)
  static const Color accentGreen = Color(0xFF1DB954);
  static const Color accentBlue = Color(0xFF4F8EF7);
  static const Color accentOrange = Color(0xFFFF6D00);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color success = Color(0xFF388E3C);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // ─── Shadows ────────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get bottomSheetShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 24,
          offset: const Offset(0, -4),
        ),
      ];

  // ─── Light Theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',

      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: error),
        ),
        hintStyle: const TextStyle(color: textHint, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),

      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: divider),
        ),
        margin: EdgeInsets.zero,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 0,
      ),

      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -1),
        displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5),
        displaySmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3),
        headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3),
        headlineSmall: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        titleLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        titleMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        titleSmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textSecondary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: textSecondary),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        labelSmall: TextStyle(fontSize: 11, color: textSecondary),
      ),

      iconTheme: const IconThemeData(color: textPrimary, size: 24),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryLight,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: background,
        selectedColor: primary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: divider),
        ),
      ),
    );
  }

  // ─── Map Style ────────────────────────────────────────────────────────────────
  static const String mapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"water","stylers":[{"color":"#c9c9c9"}]}
  ]''';
}

// ─── Text Styles shorthand ───────────────────────────────────────────────────
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppTheme.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppTheme.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppTheme.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppTheme.textPrimary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppTheme.textSecondary,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: Colors.white,
  );

  static const TextStyle price = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppTheme.textPrimary,
    letterSpacing: -0.5,
  );
}

// ─── Spacing ─────────────────────────────────────────────────────────────────
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// ─── Border Radius ────────────────────────────────────────────────────────────
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
}