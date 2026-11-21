import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Écrans épinglés en haut du Navigateur (Windows).
class FavoritesController extends StateNotifier<List<String>> {
  FavoritesController() : super(const []) {
    _load();
  }

  static const _key = 'fav_routes';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getStringList(_key) ?? const [];
    } catch (_) {}
  }

  Future<void> toggle(String route) async {
    state = state.contains(route) ? state.where((r) => r != route).toList() : [...state, route];
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_key, state);
    } catch (_) {}
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesController, List<String>>((ref) => FavoritesController());
