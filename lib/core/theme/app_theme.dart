import 'dart:ui';

import 'package:flutter/material.dart';

import '../display/display_prefs.dart';

/// Thèmes proposés. Chaque thème est complet (clair OU sombre) : le choix
/// du thème remplace l'ancien couple « mode » + « style ».
enum AppThemePreset {
  nuitBancaire,
  clairPro,
  ocean,
  emeraude,
  graphite,
  violetNuit,
  sepia,
  contraste,
}

class _Palette {
  final bool dark;
  final Color bg, panel, panel2, border, text, muted, accent, onAccent, pos, neg, warn, info;
  const _Palette({
    required this.dark,
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    this.pos = const Color(0xFF2EBD85),
    this.neg = const Color(0xFFF6465D),
    this.warn = const Color(0xFFF5A524),
    this.info = const Color(0xFF4C8DFF),
  });
}

const Map<AppThemePreset, _Palette> _palettes = {
  AppThemePreset.nuitBancaire: _Palette(
    dark: true, bg: Color(0xFF0B1220), panel: Color(0xFF111A2B), panel2: Color(0xFF0E1626),
    border: Color(0xFF1F2A40), text: Color(0xFFE6EBF5), muted: Color(0xFF8FA0BF),
    accent: Color(0xFFC9A227), onAccent: Color(0xFF0B1220),
  ),
  AppThemePreset.clairPro: _Palette(
    dark: false, bg: Color(0xFFF4F6FA), panel: Color(0xFFFFFFFF), panel2: Color(0xFFEEF1F6),
    border: Color(0xFFD5DCE8), text: Color(0xFF111827), muted: Color(0xFF5B6577),
    accent: Color(0xFF0F3D5C), onAccent: Color(0xFFFFFFFF),
    pos: Color(0xFF1B8A5A), neg: Color(0xFFC62F3F), warn: Color(0xFFB36B00), info: Color(0xFF1F5FBF),
  ),
  AppThemePreset.ocean: _Palette(
    dark: true, bg: Color(0xFF07202E), panel: Color(0xFF0D2F44), panel2: Color(0xFF0A2638),
    border: Color(0xFF18445F), text: Color(0xFFE4F1F5), muted: Color(0xFF8FB4C4),
    accent: Color(0xFF2EC4B6), onAccent: Color(0xFF07202E),
  ),
  AppThemePreset.emeraude: _Palette(
    dark: true, bg: Color(0xFF08150F), panel: Color(0xFF0F2418), panel2: Color(0xFF0B1C13),
    border: Color(0xFF1B3A2A), text: Color(0xFFE3F2E8), muted: Color(0xFF8DB39C),
    accent: Color(0xFF2EBD85), onAccent: Color(0xFF08150F),
  ),
  AppThemePreset.graphite: _Palette(
    dark: true, bg: Color(0xFF141414), panel: Color(0xFF1E1E1E), panel2: Color(0xFF181818),
    border: Color(0xFF333333), text: Color(0xFFEDEDED), muted: Color(0xFFA0A0A0),
    accent: Color(0xFF8AB4F8), onAccent: Color(0xFF141414),
  ),
  AppThemePreset.violetNuit: _Palette(
    dark: true, bg: Color(0xFF120E22), panel: Color(0xFF1B1533), panel2: Color(0xFF16102B),
    border: Color(0xFF2E2552), text: Color(0xFFEAE6F7), muted: Color(0xFFA79FC8),
    accent: Color(0xFF9D7CFF), onAccent: Color(0xFF120E22),
  ),
  AppThemePreset.sepia: _Palette(
    dark: false, bg: Color(0xFFF3ECDD), panel: Color(0xFFFBF6EA), panel2: Color(0xFFEFE6D2),
    border: Color(0xFFDCCFB4), text: Color(0xFF2B2118), muted: Color(0xFF6B5A45),
    accent: Color(0xFF8A5A2B), onAccent: Color(0xFFFFFFFF),
    pos: Color(0xFF2E7D4F), neg: Color(0xFFB3342B), warn: Color(0xFF9A5B00), info: Color(0xFF2F5F9E),
  ),
  AppThemePreset.contraste: _Palette(
    dark: true, bg: Color(0xFF000000), panel: Color(0xFF0A0A0A), panel2: Color(0xFF000000),
    border: Color(0xFFFFFFFF), text: Color(0xFFFFFFFF), muted: Color(0xFFD0D0D0),
    accent: Color(0xFFFFE600), onAccent: Color(0xFF000000),
    pos: Color(0xFF00FF88), neg: Color(0xFFFF5A5A), warn: Color(0xFFFFB000), info: Color(0xFF6CB6FF),
  ),
};

extension AppThemePresetInfo on AppThemePreset {
  _Palette get _p => _palettes[this]!;

  String get label => const [
        'Nuit bancaire',
        'Clair professionnel',
        'Océan',
        'Émeraude',
        'Graphite',
        'Violet nuit',
        'Sépia confort',
        'Contraste élevé',
      ][index];

  String get description => const [
        'Bleu nuit et or, esprit salle de marché',
        'Fond clair, bleu marine, sobre',
        'Bleu profond et turquoise',
        'Vert sombre et émeraude',
        'Gris anthracite, accent bleu clair',
        'Violet sombre, accent lavande',
        'Tons chauds, reposant pour les yeux',
        'Noir et jaune, lisibilité maximale',
      ][index];

  bool get isDark => _p.dark;
  Color get swatch => _p.accent;
  Color get previewBg => _p.bg;
  Color get previewPanel => _p.panel;
  Color get previewBorder => _p.border;
}

/// Couleurs sémantiques supplémentaires (gain, perte, alerte...) accessibles
/// via `Theme.of(context).extension<AppColors>()` ou `context.appColors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color positive, negative, warning, info, panel2, border, muted;
  const AppColors({
    required this.positive,
    required this.negative,
    required this.warning,
    required this.info,
    required this.panel2,
    required this.border,
    required this.muted,
  });

  @override
  AppColors copyWith({Color? positive, Color? negative, Color? warning, Color? info, Color? panel2, Color? border, Color? muted}) =>
      AppColors(
        positive: positive ?? this.positive,
        negative: negative ?? this.negative,
        warning: warning ?? this.warning,
        info: info ?? this.info,
        panel2: panel2 ?? this.panel2,
        border: border ?? this.border,
        muted: muted ?? this.muted,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      panel2: Color.lerp(panel2, other.panel2, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }

  static const fallback = AppColors(
    positive: Color(0xFF2EBD85),
    negative: Color(0xFFF6465D),
    warning: Color(0xFFF5A524),
    info: Color(0xFF4C8DFF),
    panel2: Color(0xFF0E1626),
    border: Color(0xFF1F2A40),
    muted: Color(0xFF8FA0BF),
  );
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.fallback;
}

class AppTheme {
  /// Thème complet pour un preset, avec la police et la densité choisies.
  static ThemeData build(
    AppThemePreset preset, {
    AppFont font = AppFont.ibmPlex,
    ListDensity density = ListDensity.comfortable,
  }) {
    final c = _palettes[preset]!;
    final brightness = c.dark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.info,
      onSecondary: c.dark ? c.bg : Colors.white,
      error: c.neg,
      onError: c.dark ? c.bg : Colors.white,
      surface: c.panel,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      outline: c.border,
      outlineVariant: c.border,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.panel2,
      surfaceContainer: c.panel,
      surfaceContainerHigh: c.panel,
      surfaceContainerHighest: c.panel2,
      primaryContainer: c.accent.withValues(alpha: 0.18),
      onPrimaryContainer: c.text,
      secondaryContainer: c.info.withValues(alpha: 0.18),
      onSecondaryContainer: c.text,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    final textTheme = base.apply(
      fontFamily: font.family,
      bodyColor: c.text,
      displayColor: c.text,
    );
    final side = BorderSide(color: c.border);
    final radius = BorderRadius.circular(10);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: font.family,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.panel,
      visualDensity: density.visual,
      textTheme: textTheme,
      dividerColor: c.border,
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      iconTheme: IconThemeData(color: c.muted),
      extensions: [
        AppColors(
          positive: c.pos,
          negative: c.neg,
          warning: c.warn,
          info: c.info,
          panel2: c.panel2,
          border: c.border,
          muted: c.muted,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: c.panel2,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        shape: Border(bottom: side),
        titleTextStyle: TextStyle(
          fontFamily: font.family,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
        iconTheme: IconThemeData(color: c.muted),
        actionsIconTheme: IconThemeData(color: c.muted),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.text,
        selectedColor: c.accent,
        selectedTileColor: c.accent.withValues(alpha: 0.10),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: c.panel2, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: side),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: side),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.panel2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: side),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: side),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.accent, width: 1.5)),
        labelStyle: TextStyle(color: c.muted),
        hintStyle: TextStyle(color: c.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.accent)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.panel2,
        selectedColor: c.accent.withValues(alpha: 0.2),
        side: side,
        labelStyle: TextStyle(color: c.text, fontFamily: font.family),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.text,
        unselectedLabelColor: c.muted,
        indicatorColor: c.accent,
        dividerColor: c.border,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.panel2,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accent.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.border),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.panel,
        contentTextStyle: TextStyle(color: c.text, fontFamily: font.family),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: side),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.border),
    );
  }
}

/// Style de texte à utiliser pour tout affichage de montant. Selon le
/// réglage « Police des montants », les chiffres sont à chasse fixe
/// (alignés verticalement dans les listes) ou proportionnels.
TextStyle amountTextStyle({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: DisplayPrefs.current.tabularAmounts ? const [FontFeature.tabularFigures()] : null,
  );
}
