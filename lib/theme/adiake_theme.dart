import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'adiake_colors.dart';

abstract class FamanhTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: FamanhColors.primary,
      onPrimary: FamanhColors.onPrimary,
      primaryContainer: FamanhColors.primaryContainer,
      onPrimaryContainer: Colors.white,
      secondary: FamanhColors.secondary,
      onSecondary: FamanhColors.onPrimary,
      secondaryContainer: FamanhColors.secondaryContainer,
      onSecondaryContainer: FamanhColors.onSecondaryContainer,
      tertiary: FamanhColors.tertiary,
      tertiaryContainer: FamanhColors.tertiaryContainer,
      error: FamanhColors.error,
      onError: FamanhColors.onError,
      surface: FamanhColors.surface,
      onSurface: FamanhColors.onSurface,
      surfaceContainerLowest: FamanhColors.surfaceContainerLowest,
      outlineVariant: FamanhColors.outlineVariant,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: FamanhColors.onSurface),
      headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: FamanhColors.onSurface),
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: FamanhColors.onSurface),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: FamanhColors.onSurface),
      titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: FamanhColors.onSurface),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FamanhColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: FamanhColors.background.withValues(alpha: 0.85),
        foregroundColor: FamanhColors.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: FamanhColors.onBackground,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FamanhColors.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FamanhColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FamanhColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FamanhColors.primaryContainer, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FamanhColors.primaryContainer,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// Alias rétro-compatible
typedef AdiakeTheme = FamanhTheme;


