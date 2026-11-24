import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'chart_style.dart';

const String _presetPrefsKey = 'theme_preset_v2';
const String _oldPresetPrefsKey = 'theme_preset';
const String _oldModePrefsKey = 'theme_mode';

/// Gère le thème choisi (8 thèmes complets), avec mémorisation. Les anciens
/// réglages (style + mode clair/sombre) sont convertis automatiquement.
class ThemePresetController extends StateNotifier<AppThemePreset> {
  ThemePresetController() : super(AppThemePreset.nuitBancaire) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_presetPrefsKey);
      if (saved != null) {
        state = AppThemePreset.values.firstWhere(
          (p) => p.name == saved,
          orElse: () => AppThemePreset.nuitBancaire,
        );
        return;
      }
      // Migration depuis l'ancien système (style + mode).
      final oldPreset = prefs.getString(_oldPresetPrefsKey);
      final oldMode = prefs.getString(_oldModePrefsKey);
      AppThemePreset migrated;
      switch (oldPreset) {
        case 'colore':
          migrated = AppThemePreset.violetNuit;
          break;
        case 'nature':
          migrated = AppThemePreset.emeraude;
          break;
        case 'minimaliste':
          migrated = AppThemePreset.graphite;
          break;
        default:
          migrated = oldMode == 'light' ? AppThemePreset.clairPro : AppThemePreset.nuitBancaire;
      }
      state = migrated;
    } catch (_) {}
  }

  Future<void> setPreset(AppThemePreset preset) async {
    state = preset;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_presetPrefsKey, preset.name);
    } catch (_) {}
  }
}

final themePresetProvider = StateNotifierProvider<ThemePresetController, AppThemePreset>((ref) {
  return ThemePresetController();
});


const String _chartPrefsKey = 'chart_style_v1';

/// Réglages des graphiques (couleurs + styles), mémorisés sur l'appareil.
class ChartStyleController extends StateNotifier<ChartStyle> {
  ChartStyleController() : super(ChartStyle.defaults) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chartPrefsKey);
      if (raw != null && mounted) state = ChartStyle.decode(raw);
    } catch (_) {}
  }

  Future<void> set(ChartStyle style) async {
    state = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chartPrefsKey, style.encode());
    } catch (_) {}
  }

  Future<void> reset() => set(ChartStyle.defaults);
}

final chartStyleProvider = StateNotifierProvider<ChartStyleController, ChartStyle>((ref) {
  return ChartStyleController();
});
