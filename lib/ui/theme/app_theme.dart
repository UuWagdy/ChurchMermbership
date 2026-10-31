import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquidify/liquidify.dart';

/// AppTheme manages the glassmorphism aesthetic, dynamic color palettes,
/// and high-contrast typography across both Light and Dark modes.
class AppTheme {
  AppTheme._();

  /// Default Church Membership Indigo
  static const Color defaultPrimary = Color(0xFF1A237E);

  /// Computes whether text on [color] should be dark or white for maximum contrast (WCAG AAA).
  static Color getContrastingTextColor(Color color) {
    // Relative luminance threshold: 0.45
    return color.computeLuminance() > 0.45
        ? const Color(0xFF0F172A)
        : Colors.white;
  }

  /// Calculates a brightness-adjusted version of [color] suitable for dark mode accentuation.
  static Color getAdaptiveAccent(Color color, bool isDark) {
    if (!isDark) return color;
    // In dark mode, ensure color is luminous enough against dark slate surfaces
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.40) {
      return hsl.withLightness(0.58).toColor();
    }
    return color;
  }

  /// Returns LiquidGlassOptions tailored to the current brightness and primary color
  static LiquidGlassOptions getLiquidGlassOptions({
    required bool isDark,
    required Color primaryColor,
  }) {
    if (isDark) {
      return LiquidGlassOptions(
        blur: 22.0,
        opacity: 0.78,
        tint: const Color(0xFF111827).withValues(alpha: 0.75),
        borderWidth: 1.2,
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            primaryColor.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        glassGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            primaryColor.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
        refraction: 0.35,
        interactive: true,
        force: true,
        enabled: true,
      );
    }

    // Light mode glass
    return LiquidGlassOptions(
      blur: 20.0,
      opacity: 0.82,
      tint: Colors.white.withValues(alpha: 0.70),
      borderWidth: 1.2,
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.95),
          primaryColor.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.40),
        ],
      ),
      glassGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.40),
          primaryColor.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.10),
        ],
      ),
      shadows: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 8),
          spreadRadius: -2,
        ),
      ],
      refraction: 0.40,
      interactive: true,
      force: true,
      enabled: true,
    );
  }

  /// Builds the complete Light Theme
  static ThemeData buildLightTheme(Color primary) {
    final contrastOnPrimary = getContrastingTextColor(primary);

    // Deep high-contrast text colors for light background
    const textPrimary = Color(0xFF0F172A); // Slate 900
    const textSecondary = Color(0xFF334155); // Slate 700
    const textMuted = Color(0xFF64748B); // Slate 500

    const scaffoldBg = Color(0xFFF8FAFC); // Slate 50
    const surfaceBg = Colors.white;

    final baseTextTheme = GoogleFonts.cairoTextTheme(ThemeData.light().textTheme);
    final highContrastTextTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
      displayMedium: baseTextTheme.displayMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
      displaySmall: baseTextTheme.displaySmall?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      titleLarge: baseTextTheme.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
      titleMedium: baseTextTheme.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      titleSmall: baseTextTheme.titleSmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w600),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w400),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: textMuted, fontWeight: FontWeight.w400),
      labelLarge: baseTextTheme.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: contrastOnPrimary,
        primaryContainer: primary.withValues(alpha: 0.12),
        onPrimaryContainer: primary,
        secondary: const Color(0xFF0284C7),
        onSecondary: Colors.white,
        surface: surfaceBg,
        onSurface: textPrimary,
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        outline: const Color(0xFFCBD5E1),
        outlineVariant: const Color(0xFFE2E8F0),
      ),
      textTheme: highContrastTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceBg.withValues(alpha: 0.88),
        elevation: 2,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: contrastOnPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.95),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: GoogleFonts.cairo(color: textSecondary, fontWeight: FontWeight.w600),
        hintStyle: GoogleFonts.cairo(color: textMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        titleTextStyle: GoogleFonts.cairo(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 24,
      ),
    );
  }

  /// Builds the complete Dark Theme
  static ThemeData buildDarkTheme(Color primary) {
    final adaptivePrimary = getAdaptiveAccent(primary, true);
    final contrastOnPrimary = getContrastingTextColor(adaptivePrimary);

    // Ultra-crisp high-contrast text colors for dark background
    const textPrimary = Color(0xFFF8FAFC); // Slate 50
    const textSecondary = Color(0xFFCBD5E1); // Slate 300
    const textMuted = Color(0xFF94A3B8); // Slate 400

    const scaffoldBg = Color(0xFF090D16); // Deep Obsidian
    const surfaceBg = Color(0xFF151E2E); // Deep Slate surface

    final baseTextTheme = GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme);
    final highContrastTextTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
      displayMedium: baseTextTheme.displayMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
      displaySmall: baseTextTheme.displaySmall?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      titleLarge: baseTextTheme.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
      titleMedium: baseTextTheme.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      titleSmall: baseTextTheme.titleSmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w600),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w400),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: textMuted, fontWeight: FontWeight.w400),
      labelLarge: baseTextTheme.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: adaptivePrimary,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.dark(
        primary: adaptivePrimary,
        onPrimary: contrastOnPrimary,
        primaryContainer: adaptivePrimary.withValues(alpha: 0.22),
        onPrimaryContainer: Colors.white,
        secondary: const Color(0xFF38BDF8),
        onSecondary: const Color(0xFF0F172A),
        surface: surfaceBg,
        onSurface: textPrimary,
        surfaceContainerHighest: const Color(0xFF1E293B),
        outline: const Color(0xFF334155),
        outlineVariant: const Color(0xFF1E293B),
      ),
      textTheme: highContrastTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceBg.withValues(alpha: 0.82),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: adaptivePrimary,
          foregroundColor: contrastOnPrimary,
          elevation: 3,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: adaptivePrimary,
          side: BorderSide(color: adaptivePrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B).withValues(alpha: 0.88),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: adaptivePrimary, width: 2),
        ),
        labelStyle: GoogleFonts.cairo(color: textSecondary, fontWeight: FontWeight.w600),
        hintStyle: GoogleFonts.cairo(color: textMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF151E2E).withValues(alpha: 0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
        titleTextStyle: GoogleFonts.cairo(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
        space: 24,
      ),
    );
  }
}
