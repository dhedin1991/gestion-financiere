import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themePrefsKey = 'theme_mode';

/// Gère le mode de thème choisi par l'utilisateur (clair, sombre, ou
/// automatique selon le téléphone/PC), avec mémorisation entre les
/// ouvertures de l'application.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themePrefsKey);
    switch (saved) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_themePrefsKey, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_themePrefsKey, 'dark');
        break;
      case ThemeMode.system:
        await prefs.setString(_themePrefsKey, 'system');
        break;
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});
