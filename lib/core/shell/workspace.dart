import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/modules.dart';

/// État de l'espace de travail Windows : onglets/fenêtres ouverts, onglet
/// actif, ordre d'empilement et géométrie des fenêtres en mode cascade.
class WorkspaceState {
  final List<String> tabs; // routes ouvertes
  final String? active;
  final List<String> zOrder; // du fond vers le dessus
  final Map<String, Rect> rects; // géométrie (mode cascade), en pixels

  const WorkspaceState({
    this.tabs = const ['/'],
    this.active = '/',
    this.zOrder = const ['/'],
    this.rects = const {},
  });

  WorkspaceState copyWith({List<String>? tabs, String? active, bool clearActive = false, List<String>? zOrder, Map<String, Rect>? rects}) {
    return WorkspaceState(
      tabs: tabs ?? this.tabs,
      active: clearActive ? null : (active ?? this.active),
      zOrder: zOrder ?? this.zOrder,
      rects: rects ?? this.rects,
    );
  }
}

class WorkspaceController extends StateNotifier<WorkspaceState> {
  WorkspaceController() : super(const WorkspaceState()) {
    _restore();
  }

  static const _tabsKey = 'ws_tabs';

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool('disp_restore') ?? false)) return;
      final saved = (p.getStringList(_tabsKey) ?? const <String>[]).where((r) => moduleForRoute(r) != null).toList();
      if (saved.isNotEmpty) {
        state = WorkspaceState(tabs: saved, active: saved.first, zOrder: saved);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_tabsKey, state.tabs);
    } catch (_) {}
  }

  /// Appelé quand l'adresse du routeur change : ouvre l'onglet si besoin.
  void syncLocation(String route) {
    if (moduleForRoute(route) == null) return;
    if (state.tabs.contains(route)) {
      if (state.active != route) state = state.copyWith(active: route);
      return;
    }
    state = state.copyWith(tabs: [...state.tabs, route], active: route, zOrder: [...state.zOrder, route]);
    _persist();
  }

  /// Ferme un onglet ; renvoie la route à afficher ensuite (ou null s'il n'en reste aucune).
  String? close(String route) {
    final idx = state.tabs.indexOf(route);
    if (idx < 0) return state.active;
    final tabs = [...state.tabs]..removeAt(idx);
    final z = state.zOrder.where((r) => r != route).toList();
    final rects = Map<String, Rect>.from(state.rects)..remove(route);
    String? next = state.active;
    if (state.active == route) {
      next = tabs.isEmpty ? null : tabs[idx.clamp(0, tabs.length - 1)];
    }
    state = WorkspaceState(tabs: tabs, active: next, zOrder: z, rects: rects);
    _persist();
    return next;
  }

  void closeAllExcept(String route) {
    state = WorkspaceState(tabs: [route], active: route, zOrder: [route], rects: const {});
    _persist();
  }

  void focus(String route) {
    if (!state.tabs.contains(route)) return;
    final z = [...state.zOrder.where((r) => r != route), route];
    state = state.copyWith(active: route, zOrder: z);
  }

  void setRect(String route, Rect r) {
    state = state.copyWith(rects: {...state.rects, route: r});
  }
}

final workspaceProvider = StateNotifierProvider<WorkspaceController, WorkspaceState>((ref) => WorkspaceController());
