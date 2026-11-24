import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/theme/chart_style.dart';

void main() {
  test('sauvegarde et relecture des réglages de graphiques', () {
    final s = ChartStyle.defaults
        .withPreset(kChartPresets.firstWhere((p) => p.id == 'neon'))
        .copyWith(lineMode: ChartLineMode.step, lineWidth: 3.5, barShape: ChartBarShape.pill, thickness: 1.3, showGrid: false)
        .withColors(positive: const Color(0xFF123456));
    final back = ChartStyle.decode(s.encode());
    expect(back.presetId, 'perso');
    expect(back.positive, const Color(0xFF123456));
    expect(back.lineMode, ChartLineMode.step);
    expect(back.barShape, ChartBarShape.pill);
    expect(back.lineWidth, 3.5);
    expect(back.thickness, 1.3);
    expect(back.showGrid, false);
    expect(back.palette, isNotEmpty);
  });

  test('réglages absents ou abîmés : valeurs d\'origine', () {
    expect(ChartStyle.decode(null).presetId, 'defaut');
    expect(ChartStyle.decode('pas du json').presetId, 'defaut');
    expect(ChartStyle.decode('{"width": 99}').lineWidth, 5.0);
  });

  test('palette : couleur d\'origine sans palette, palette sinon', () {
    const base = Color(0xFF000001);
    expect(ChartStyle.defaults.seriesColor(2, base), base);
    final neon = ChartStyle.defaults.withPreset(kChartPresets.firstWhere((p) => p.id == 'neon'));
    expect(neon.seriesColor(0, base), neon.palette!.first);
    expect(neon.seriesColor(neon.palette!.length, base), neon.palette!.first);
  });

  test('retour au thème pour une couleur', () {
    final s = ChartStyle.defaults.withColors(negative: const Color(0xFF111111)).withColors(clearNegative: true);
    expect(s.negative, isNull);
  });
}
