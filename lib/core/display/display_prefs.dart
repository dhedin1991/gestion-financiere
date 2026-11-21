import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Polices proposées (toutes embarquées dans l'application : aucun
/// téléchargement, l'app reste 100 % hors ligne). « Segoe UI » est la police
/// système de Windows (sur Android elle retombe sur la police par défaut).
enum AppFont { ibmPlex, inter, roboto, openSans, sourceSans, lato, atkinson, segoe }

extension AppFontInfo on AppFont {
  String get label {
    switch (this) {
      case AppFont.ibmPlex:
        return 'IBM Plex Sans';
      case AppFont.inter:
        return 'Inter';
      case AppFont.roboto:
        return 'Roboto';
      case AppFont.openSans:
        return 'Open Sans';
      case AppFont.sourceSans:
        return 'Source Sans';
      case AppFont.lato:
        return 'Lato';
      case AppFont.atkinson:
        return 'Atkinson (très lisible)';
      case AppFont.segoe:
        return 'Segoe UI (Windows)';
    }
  }

  String get family {
    switch (this) {
      case AppFont.ibmPlex:
        return 'IBMPlexSans';
      case AppFont.inter:
        return 'Inter';
      case AppFont.roboto:
        return 'Roboto';
      case AppFont.openSans:
        return 'OpenSans';
      case AppFont.sourceSans:
        return 'SourceSans3';
      case AppFont.lato:
        return 'Lato';
      case AppFont.atkinson:
        return 'AtkinsonHyperlegible';
      case AppFont.segoe:
        return 'Segoe UI';
    }
  }
}

enum ListDensity { compact, comfortable, airy }

extension ListDensityInfo on ListDensity {
  String get label => const ['Compacte', 'Confortable', 'Aérée'][index];
  VisualDensity get visual => const [
        VisualDensity(horizontal: -2, vertical: -2),
        VisualDensity.standard,
        VisualDensity(horizontal: 1, vertical: 1),
      ][index];
}

enum TextSizeChoice { small, normal, large }

extension TextSizeInfo on TextSizeChoice {
  String get label => const ['Petite', 'Normale', 'Grande'][index];
  double get scale => const [0.92, 1.0, 1.12][index];
}

enum ThousandsSeparator { space, dot, comma }

extension ThousandsSeparatorInfo on ThousandsSeparator {
  String get label => const ['Espace', 'Point', 'Virgule'][index];
  String get char => const [' ', '.', ','][index];
}

/// Dispositions possibles des fenêtres de l'espace de travail (Windows).
enum WindowLayout { tabs, cascade, columns, tiles }

extension WindowLayoutInfo on WindowLayout {
  String get label => const ['Onglets', 'Cascade', 'Colonnes', 'Mosaïque'][index];
  String get hint => const [
        'Une fenêtre à la fois',
        'Fenêtres qui se chevauchent',
        'Côte à côte',
        'Grille de fenêtres',
      ][index];
}

const int kZoomMin = 75;
const int kZoomMax = 150;
const int kZoomStep = 5;

List<int> get kZoomSteps => [for (int z = kZoomMin; z <= kZoomMax; z += kZoomStep) z];

/// Préférences d'affichage de l'application (Paramètres > Affichage).
@immutable
class DisplayPrefs {
  final int zoom; // pourcentage, 75..150 par pas de 5
  final AppFont font;
  final ListDensity density;
  final TextSizeChoice textSize;
  final bool tabularAmounts;
  final ThousandsSeparator separator;
  final bool followSystemTheme;
  final WindowLayout windowLayout;
  final bool allowDetach;
  final bool openHomeAtStart;
  final bool restoreWindows;
  final bool searchShortcut;
  final bool searchArchived;
  final bool hideAmounts; // mode confidentialité

  const DisplayPrefs({
    this.zoom = 100,
    this.font = AppFont.ibmPlex,
    this.density = ListDensity.comfortable,
    this.textSize = TextSizeChoice.normal,
    this.tabularAmounts = true,
    this.separator = ThousandsSeparator.space,
    this.followSystemTheme = false,
    this.windowLayout = WindowLayout.tabs,
    this.allowDetach = true,
    this.openHomeAtStart = true,
    this.restoreWindows = false,
    this.searchShortcut = true,
    this.searchArchived = false,
    this.hideAmounts = false,
  });

  DisplayPrefs copyWith({
    int? zoom,
    AppFont? font,
    ListDensity? density,
    TextSizeChoice? textSize,
    bool? tabularAmounts,
    ThousandsSeparator? separator,
    bool? followSystemTheme,
    WindowLayout? windowLayout,
    bool? allowDetach,
    bool? openHomeAtStart,
    bool? restoreWindows,
    bool? searchShortcut,
    bool? searchArchived,
    bool? hideAmounts,
  }) {
    return DisplayPrefs(
      zoom: zoom ?? this.zoom,
      font: font ?? this.font,
      density: density ?? this.density,
      textSize: textSize ?? this.textSize,
      tabularAmounts: tabularAmounts ?? this.tabularAmounts,
      separator: separator ?? this.separator,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      windowLayout: windowLayout ?? this.windowLayout,
      allowDetach: allowDetach ?? this.allowDetach,
      openHomeAtStart: openHomeAtStart ?? this.openHomeAtStart,
      restoreWindows: restoreWindows ?? this.restoreWindows,
      searchShortcut: searchShortcut ?? this.searchShortcut,
      searchArchived: searchArchived ?? this.searchArchived,
      hideAmounts: hideAmounts ?? this.hideAmounts,
    );
  }

  /// Valeur courante, lisible depuis du code qui n'a pas accès à Riverpod
  /// (formatage des montants, style des chiffres).
  static DisplayPrefs current = const DisplayPrefs();
}

int clampZoom(int z) {
  final c = z.clamp(kZoomMin, kZoomMax);
  return kZoomMin + ((c - kZoomMin) / kZoomStep).round() * kZoomStep;
}

class DisplayPrefsController extends StateNotifier<DisplayPrefs> {
  DisplayPrefsController() : super(const DisplayPrefs()) {
    _load();
  }

  static const _k = 'disp_';

  T _enum<T>(List<T> values, int? i, T fallback) =>
      (i != null && i >= 0 && i < values.length) ? values[i] : fallback;

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = DisplayPrefs(
        zoom: clampZoom(p.getInt('${_k}zoom') ?? 100),
        font: _enum(AppFont.values, p.getInt('${_k}font'), AppFont.ibmPlex),
        density: _enum(ListDensity.values, p.getInt('${_k}density'), ListDensity.comfortable),
        textSize: _enum(TextSizeChoice.values, p.getInt('${_k}textsize'), TextSizeChoice.normal),
        tabularAmounts: p.getBool('${_k}tabular') ?? true,
        separator: _enum(ThousandsSeparator.values, p.getInt('${_k}sep'), ThousandsSeparator.space),
        followSystemTheme: p.getBool('${_k}follow') ?? false,
        windowLayout: _enum(WindowLayout.values, p.getInt('${_k}layout'), WindowLayout.tabs),
        allowDetach: p.getBool('${_k}detach') ?? true,
        openHomeAtStart: p.getBool('${_k}home') ?? true,
        restoreWindows: p.getBool('${_k}restore') ?? false,
        searchShortcut: p.getBool('${_k}searchkey') ?? true,
        searchArchived: p.getBool('${_k}searcharch') ?? false,
        hideAmounts: p.getBool('${_k}hide') ?? false,
      );
      DisplayPrefs.current = s;
      state = s;
    } catch (_) {
      // Préférences illisibles : on garde les valeurs par défaut.
    }
  }

  Future<void> update(DisplayPrefs next) async {
    DisplayPrefs.current = next;
    state = next;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('${_k}zoom', next.zoom);
      await p.setInt('${_k}font', next.font.index);
      await p.setInt('${_k}density', next.density.index);
      await p.setInt('${_k}textsize', next.textSize.index);
      await p.setBool('${_k}tabular', next.tabularAmounts);
      await p.setInt('${_k}sep', next.separator.index);
      await p.setBool('${_k}follow', next.followSystemTheme);
      await p.setInt('${_k}layout', next.windowLayout.index);
      await p.setBool('${_k}detach', next.allowDetach);
      await p.setBool('${_k}home', next.openHomeAtStart);
      await p.setBool('${_k}restore', next.restoreWindows);
      await p.setBool('${_k}searchkey', next.searchShortcut);
      await p.setBool('${_k}searcharch', next.searchArchived);
      await p.setBool('${_k}hide', next.hideAmounts);
    } catch (_) {}
  }

  void setZoom(int z) => update(state.copyWith(zoom: clampZoom(z)));
  void zoomIn() => setZoom(state.zoom + kZoomStep);
  void zoomOut() => setZoom(state.zoom - kZoomStep);
  void toggleHideAmounts() => update(state.copyWith(hideAmounts: !state.hideAmounts));
}

final displayPrefsProvider = StateNotifierProvider<DisplayPrefsController, DisplayPrefs>((ref) {
  return DisplayPrefsController();
});
