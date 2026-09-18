import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Les différents styles visuels proposés à l'utilisateur, indépendants
/// du mode clair/sombre (qui reste géré séparément par ThemeModeController).
enum AppThemePreset { bancaire, colore, nature, minimaliste }

extension AppThemePresetLabel on AppThemePreset {
  String get label {
    switch (this) {
      case AppThemePreset.bancaire:
        return 'Bancaire Pro';
      case AppThemePreset.colore:
        return 'Coloré';
      case AppThemePreset.nature:
        return 'Nature';
      case AppThemePreset.minimaliste:
        return 'Minimaliste';
    }
  }

  String get description {
    switch (this) {
      case AppThemePreset.bancaire:
        return 'Sobre et contrasté, esprit application bancaire';
      case AppThemePreset.colore:
        return 'Vif et énergique, beaucoup de couleurs';
      case AppThemePreset.nature:
        return 'Tons verts et chaleureux, apaisant';
      case AppThemePreset.minimaliste:
        return 'Noir, blanc et gris, épuré au maximum';
    }
  }

  /// Couleur représentative utilisée pour la vignette de prévisualisation
  /// dans le sélecteur de style.
  Color get swatch {
    switch (this) {
      case AppThemePreset.bancaire:
        return const Color(0xFF0F3D5C);
      case AppThemePreset.colore:
        return const Color(0xFF7C3AED);
      case AppThemePreset.nature:
        return const Color(0xFF2D6A4F);
      case AppThemePreset.minimaliste:
        return const Color(0xFF2B2D31);
    }
  }
}

class _PresetColors {
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color danger;
  final Color backgroundLight;
  final Color backgroundDark;
  final Color surfaceDark;
  final Color appBarDark;

  const _PresetColors({
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.danger,
    required this.backgroundLight,
    required this.backgroundDark,
    required this.surfaceDark,
    required this.appBarDark,
  });
}

/// Palettes et thèmes proposés dans l'application. Chaque style (preset)
/// définit ses propres couleurs pour les modes clair et sombre.
class AppTheme {
  static const Map<AppThemePreset, _PresetColors> _palettes = {
    // Sobre, contrasté, bleu profond associé à la confiance (banques).
    AppThemePreset.bancaire: _PresetColors(
      primary: Color(0xFF0F3D5C),
      primaryDark: Color(0xFF3E7CA6),
      accent: Color(0xFF16A085),
      danger: Color(0xFFE74C3C),
      backgroundLight: Color(0xFFF5F7FA),
      backgroundDark: Color(0xFF121417),
      surfaceDark: Color(0xFF1E2227),
      appBarDark: Color(0xFF1B1F24),
    ),
    // Vif et énergique : violet, orange, rose.
    AppThemePreset.colore: _PresetColors(
      primary: Color(0xFF7C3AED),
      primaryDark: Color(0xFFA78BFA),
      accent: Color(0xFFFF9F1C),
      danger: Color(0xFFEF476F),
      backgroundLight: Color(0xFFFAF7FF),
      backgroundDark: Color(0xFF17131F),
      surfaceDark: Color(0xFF241E30),
      appBarDark: Color(0xFF221B2E),
    ),
    // Tons verts et chaleureux, apaisant.
    AppThemePreset.nature: _PresetColors(
      primary: Color(0xFF2D6A4F),
      primaryDark: Color(0xFF74C69D),
      accent: Color(0xFFD4A017),
      danger: Color(0xFFBC4749),
      backgroundLight: Color(0xFFF6F8F3),
      backgroundDark: Color(0xFF141B17),
      surfaceDark: Color(0xFF1E2A22),
      appBarDark: Color(0xFF18231D),
    ),
    // Noir, blanc, gris — aucune couleur d'accent forte.
    AppThemePreset.minimaliste: _PresetColors(
      primary: Color(0xFF2B2D31),
      primaryDark: Color(0xFFC9CCD1),
      accent: Color(0xFF5C6672),
      danger: Color(0xFFB3261E),
      backgroundLight: Color(0xFFFAFAFA),
      backgroundDark: Color(0xFF121212),
      surfaceDark: Color(0xFF1C1C1E),
      appBarDark: Color(0xFF1A1A1C),
    ),
  };

  static ThemeData light(AppThemePreset preset) {
    final c = _palettes[preset]!;
    final baseTextTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: c.backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: Brightness.light,
        primary: c.primary,
        secondary: c.accent,
        error: c.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    );
  }

  static ThemeData dark(AppThemePreset preset) {
    final c = _palettes[preset]!;
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: Brightness.dark,
        primary: c.primaryDark,
        secondary: c.accent,
        error: c.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.appBarDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: baseTextTheme,
    );
  }
}

/// Style de texte à utiliser pour tout affichage de montant, avec des
/// chiffres à chasse fixe (tabular figures) : dans une liste de
/// transactions ou un tableau, les montants s'alignent verticalement au
/// lieu de "danser" à cause de la largeur variable des chiffres normaux.
/// Usage : Text(montant, style: amountTextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green))

TextStyle amountTextStyle({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
}) {
  return GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
