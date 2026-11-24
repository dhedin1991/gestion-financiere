import 'dart:convert';

import 'package:flutter/material.dart';

enum ChartLineMode { smooth, straight, step }

enum ChartBarShape { rounded, square, pill }

/// Palette prête à l'emploi (couleurs + série pour les répartitions).
class ChartPreset {
  final String id;
  final String label;
  final Color? positive;
  final Color? negative;
  final Color? warning;
  final Color? line;
  final List<Color>? palette;
  const ChartPreset(this.id, this.label, {this.positive, this.negative, this.warning, this.line, this.palette});
}

const List<ChartPreset> kChartPresets = [
  ChartPreset('defaut', 'Thème (par défaut)'),
  ChartPreset('ocean', 'Océan',
      positive: Color(0xFF14B8A6),
      negative: Color(0xFFF43F5E),
      warning: Color(0xFFF59E0B),
      line: Color(0xFF3B82F6),
      palette: [Color(0xFF3B82F6), Color(0xFF14B8A6), Color(0xFF6366F1), Color(0xFF06B6D4), Color(0xFF8B5CF6), Color(0xFF0EA5E9), Color(0xFF22D3EE)]),
  ChartPreset('pastel', 'Pastel',
      positive: Color(0xFF7BC8A4),
      negative: Color(0xFFF28B9B),
      warning: Color(0xFFF6C177),
      line: Color(0xFF8DA9F5),
      palette: [Color(0xFF8DA9F5), Color(0xFF7BC8A4), Color(0xFFF6C177), Color(0xFFF28B9B), Color(0xFFB8A4E3), Color(0xFF8ED1E0), Color(0xFFE3B7A0)]),
  ChartPreset('neon', 'Néon',
      positive: Color(0xFF00E676),
      negative: Color(0xFFFF1744),
      warning: Color(0xFFFFEA00),
      line: Color(0xFF00B0FF),
      palette: [Color(0xFF00B0FF), Color(0xFF00E676), Color(0xFFFF1744), Color(0xFFFFEA00), Color(0xFFD500F9), Color(0xFF1DE9B6), Color(0xFFFF9100)]),
  ChartPreset('soleil', 'Coucher de soleil',
      positive: Color(0xFF34D399),
      negative: Color(0xFFFB7185),
      warning: Color(0xFFFBBF24),
      line: Color(0xFFFB923C),
      palette: [Color(0xFFFB923C), Color(0xFFFB7185), Color(0xFFFBBF24), Color(0xFFF472B6), Color(0xFFA78BFA), Color(0xFFF97316), Color(0xFFE11D48)]),
  ChartPreset('daltonien', 'Daltonisme (lisible par tous)',
      positive: Color(0xFF56B4E9),
      negative: Color(0xFFE69F00),
      warning: Color(0xFFF0E442),
      line: Color(0xFFCC79A7),
      palette: [Color(0xFF56B4E9), Color(0xFFE69F00), Color(0xFF009E73), Color(0xFFF0E442), Color(0xFF0072B2), Color(0xFFD55E00), Color(0xFFCC79A7)]),
];

/// Réglages des graphiques : couleurs (revenus, dépenses, alertes, courbes,
/// série de répartition) et styles (courbes, barres, anneaux, quadrillage).
///
/// C'est une extension du thème : changer un réglage met à jour tous les
/// graphiques et indicateurs de l'application d'un seul coup. Une couleur à
/// `null` signifie « celle du thème choisi ».
class ChartStyle extends ThemeExtension<ChartStyle> {
  final String presetId;
  final Color? positive;
  final Color? negative;
  final Color? warning;
  final Color? line;
  final List<Color>? palette;
  final ChartLineMode lineMode;
  final bool fillArea;
  final double lineWidth;
  final bool showGrid;
  final ChartBarShape barShape;
  final double thickness; // multiplicateur d'épaisseur des anneaux

  const ChartStyle({
    this.presetId = 'defaut',
    this.positive,
    this.negative,
    this.warning,
    this.line,
    this.palette,
    this.lineMode = ChartLineMode.smooth,
    this.fillArea = true,
    this.lineWidth = 2.4,
    this.showGrid = true,
    this.barShape = ChartBarShape.rounded,
    this.thickness = 1.0,
  });

  static const defaults = ChartStyle();

  /// Applique une palette prête à l'emploi (les styles de tracé restent).
  ChartStyle withPreset(ChartPreset p) => ChartStyle(
        presetId: p.id,
        positive: p.positive,
        negative: p.negative,
        warning: p.warning,
        line: p.line,
        palette: p.palette,
        lineMode: lineMode,
        fillArea: fillArea,
        lineWidth: lineWidth,
        showGrid: showGrid,
        barShape: barShape,
        thickness: thickness,
      );

  /// Change une ou plusieurs couleurs : le jeu devient « personnalisé ».
  /// `clear*` remet la couleur du thème.
  ChartStyle withColors({
    Color? positive,
    Color? negative,
    Color? warning,
    Color? line,
    bool clearPositive = false,
    bool clearNegative = false,
    bool clearWarning = false,
    bool clearLine = false,
  }) =>
      ChartStyle(
        presetId: 'perso',
        positive: clearPositive ? null : (positive ?? this.positive),
        negative: clearNegative ? null : (negative ?? this.negative),
        warning: clearWarning ? null : (warning ?? this.warning),
        line: clearLine ? null : (line ?? this.line),
        palette: palette,
        lineMode: lineMode,
        fillArea: fillArea,
        lineWidth: lineWidth,
        showGrid: showGrid,
        barShape: barShape,
        thickness: thickness,
      );

  @override
  ChartStyle copyWith({
    ChartLineMode? lineMode,
    bool? fillArea,
    double? lineWidth,
    bool? showGrid,
    ChartBarShape? barShape,
    double? thickness,
  }) =>
      ChartStyle(
        presetId: presetId,
        positive: positive,
        negative: negative,
        warning: warning,
        line: line,
        palette: palette,
        lineMode: lineMode ?? this.lineMode,
        fillArea: fillArea ?? this.fillArea,
        lineWidth: lineWidth ?? this.lineWidth,
        showGrid: showGrid ?? this.showGrid,
        barShape: barShape ?? this.barShape,
        thickness: thickness ?? this.thickness,
      );

  @override
  ChartStyle lerp(ThemeExtension<ChartStyle>? other, double t) => other is ChartStyle && t >= 0.5 ? other : this;

  /// Couleur d'une série dans une répartition : la palette choisie si elle
  /// existe, sinon la couleur d'origine [fallback].
  Color seriesColor(int index, Color fallback) {
    final p = palette;
    if (p == null || p.isEmpty) return fallback;
    return p[index % p.length];
  }

  /// Rayon des barres verticales.
  BorderRadius barRadius(double width) {
    switch (barShape) {
      case ChartBarShape.square:
        return BorderRadius.zero;
      case ChartBarShape.pill:
        return BorderRadius.circular(width / 2);
      case ChartBarShape.rounded:
        return BorderRadius.vertical(top: Radius.circular(width * 0.35));
    }
  }

  // ── sauvegarde ──

  Map<String, dynamic> toJson() => {
        'preset': presetId,
        'pos': positive?.toARGB32(),
        'neg': negative?.toARGB32(),
        'warn': warning?.toARGB32(),
        'line': line?.toARGB32(),
        'palette': palette?.map((c) => c.toARGB32()).toList(),
        'mode': lineMode.name,
        'fill': fillArea,
        'width': lineWidth,
        'grid': showGrid,
        'bar': barShape.name,
        'thick': thickness,
      };

  String encode() => jsonEncode(toJson());

  static Color? _c(Object? v) => v is int ? Color(v) : null;

  static ChartStyle decode(String? raw) {
    if (raw == null) return defaults;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return ChartStyle(
        presetId: (j['preset'] as String?) ?? 'defaut',
        positive: _c(j['pos']),
        negative: _c(j['neg']),
        warning: _c(j['warn']),
        line: _c(j['line']),
        palette: (j['palette'] as List?)?.map((e) => Color(e as int)).toList(),
        lineMode: ChartLineMode.values.firstWhere((m) => m.name == j['mode'], orElse: () => ChartLineMode.smooth),
        fillArea: (j['fill'] as bool?) ?? true,
        lineWidth: ((j['width'] as num?) ?? 2.4).toDouble().clamp(1.0, 5.0),
        showGrid: (j['grid'] as bool?) ?? true,
        barShape: ChartBarShape.values.firstWhere((m) => m.name == j['bar'], orElse: () => ChartBarShape.rounded),
        thickness: ((j['thick'] as num?) ?? 1.0).toDouble().clamp(0.6, 1.6),
      );
    } catch (_) {
      return defaults;
    }
  }
}

extension ChartStyleContext on BuildContext {
  ChartStyle get chartStyle => Theme.of(this).extension<ChartStyle>() ?? ChartStyle.defaults;
}
