import 'package:flutter/material.dart';

/// Palette et thème inspirés des applications bancaires modernes :
/// sobre, contrasté, avec une couleur d'accent forte pour les montants
/// et les actions principales.
class AppTheme {
  // Couleur principale : bleu profond, associée à la confiance (banques).
  static const Color primaryColor = Color(0xFF0F3D5C);
  static const Color accentColor = Color(0xFF16A085); // vert = revenus / positif
  static const Color dangerColor = Color(0xFFE74C3C); // rouge = dépenses / négatif
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFF121417);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: accentColor,
        error: dangerColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: const Color(0xFF3E7CA6),
        secondary: accentColor,
        error: dangerColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B1F24),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardTheme(
        elevation: 0,
        color: const Color(0xFF1E2227),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
