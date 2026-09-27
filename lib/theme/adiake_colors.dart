import 'package:flutter/material.dart';

abstract class FamanhColors {
  // Charte « Famanh » — Bleu vibrant, Dark Navy & Émeraude (Identique au Back-office).
  
  /// Bleu principal de marque (#006194 / #0052FF)
  static const primary = Color(0xFF006194);
  /// Container bleu vif (#007BB9 / #0052FF)
  static const primaryContainer = Color(0xFF0052FF);
  /// Bleu clair fixe (#CCE5FF)
  static const primaryFixed = Color(0xFFCCE5FF);
  /// Accent bleu céleste
  static const primaryFixedDim = Color(0xFF93CCFF);

  /// Dégradé bleu Famanh (Logo & En-têtes)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0052FF), Color(0xFF00D2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark Navy (#0A2540 / #131B2E) - En-têtes sombres et textes forts
  static const darkNavy = Color(0xFF0A2540);

  /// Émeraude / Vert actif (#006C49)
  static const secondary = Color(0xFF006C49);
  /// Container vert pastel (#6CF8BB)
  static const secondaryContainer = Color(0xFF6CF8BB);
  static const onSecondaryContainer = Color(0xFF005236);

  /// Ambre / Warm Gold (#825100 / #FFB95F)
  static const tertiary = Color(0xFF825100);
  static const tertiaryContainer = Color(0xFFA36700);
  static const tertiaryFixed = Color(0xFFFFDDB8);
  static const tertiaryFixedDim = Color(0xFFFFB95F);
  static const onTertiaryFixedVariant = Color(0xFF653E00);

  /// Fonds et Surfaces
  static const background = Color(0xFFFAF8FF);
  static const surface = Color(0xFFFAF8FF);
  static const surfaceContainerLow = Color(0xFFF2F3FF);
  static const surfaceContainer = Color(0xFFEAEDFF);
  static const surfaceContainerHigh = Color(0xFFE2E7FF);
  static const surfaceContainerHighest = Color(0xFFDAE2FD);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceDim = Color(0xFFD2D9F4);
  static const surfaceVariant = Color(0xFFDAE2FD);

  /// Textes et Typographies
  static const onPrimary = Color(0xFFFFFFFF);
  static const onBackground = Color(0xFF131B2E);
  static const onSurface = Color(0xFF131B2E);
  static const onSurfaceVariant = Color(0xFF3F4850);

  /// Bordures et Contours
  static const outline = Color(0xFF707881);
  static const outlineVariant = Color(0xFFBFC7D2);

  /// Erreurs et Alertes
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onError = Color(0xFFFFFFFF);
  static const onErrorContainer = Color(0xFF93000A);
}

/// Alias rétro-compatible pour le code existant
typedef AdiakeColors = FamanhColors;


