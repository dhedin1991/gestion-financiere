import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Courbe d'évolution avec aire dégradée (style TradingView).
class LineAreaChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  final bool grid;

  const LineAreaChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 90,
    this.grid = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(
          series: [values],
          colors: [color],
          fill: true,
          gridColor: grid ? context.appColors.border : null,
        ),
      ),
    );
  }
}

/// Plusieurs courbes superposées (une par compte).
class MultiLineChart extends StatelessWidget {
  final List<List<double>> series;
  final List<Color> colors;
  final double height;

  const MultiLineChart({super.key, required this.series, required this.colors, this.height = 170});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(
          series: series,
          colors: colors,
          fill: false,
          gridColor: context.appColors.border,
          normalizeEach: true,
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<List<double>> series;
  final List<Color> colors;
  final bool fill;
  final Color? gridColor;
  final bool normalizeEach;

  _LinePainter({
    required this.series,
    required this.colors,
    required this.fill,
    this.gridColor,
    this.normalizeEach = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gridColor != null) {
      final gp = Paint()
        ..color = gridColor!
        ..strokeWidth = 1;
      for (var i = 1; i <= 3; i++) {
        final y = size.height * i / 4;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
      }
    }
    double gMin = double.infinity, gMax = -double.infinity;
    for (final s in series) {
      for (final v in s) {
        gMin = math.min(gMin, v);
        gMax = math.max(gMax, v);
      }
    }
    for (var si = 0; si < series.length; si++) {
      final data = series[si];
      if (data.length < 2) continue;
      var mn = gMin, mx = gMax;
      if (normalizeEach) {
        mn = data.reduce(math.min);
        mx = data.reduce(math.max);
      }
      final pad = (mx - mn).abs() < 1e-9 ? 1.0 : (mx - mn) * 0.12;
      final lo = mn - pad, hi = mx + pad;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final x = size.width * i / (data.length - 1);
        final y = size.height - ((data[i] - lo) / (hi - lo)) * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      if (fill) {
        final area = Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors[si].withValues(alpha: 0.32), colors[si].withValues(alpha: 0)],
            ).createShader(Offset.zero & size),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[si]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.series != series || old.colors != colors;
}

/// Cercle de suivi qui se remplit progressivement à l'affichage.
class RingGauge extends StatelessWidget {
  final double value; // 0..1 (peut dépasser 1 : affiché plein)
  final Color color;
  final double size;
  final double stroke;
  final String? centerText;
  final TextStyle? centerStyle;

  const RingGauge({
    super.key,
    required this.value,
    required this.color,
    this.size = 84,
    this.stroke = 9,
    this.centerText,
    this.centerStyle,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final text = centerText ?? '${(target * 100).round()} %';
    return Semantics(
      label: 'Progression $text',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => CustomPaint(
            painter: _RingPainter(
              progress: v,
              color: color,
              track: context.appColors.border,
              stroke: stroke,
            ),
            child: Center(
              child: Text(
                centerText ?? '${(v * 100).round()} %',
                style: centerStyle ??
                    TextStyle(
                      fontSize: size * 0.2,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double stroke;
  _RingPainter({required this.progress, required this.color, required this.track, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color || old.track != track;
}

class DonutSlice {
  final double value;
  final Color color;
  const DonutSlice(this.value, this.color);
}

/// Anneau de répartition (par compte, par catégorie...).
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final double size;
  final double stroke;
  final Widget? center;

  const DonutChart({super.key, required this.slices, this.size = 150, this.stroke = 18, this.center});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          painter: _DonutPainter(slices, stroke, context.appColors.border, t),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double stroke;
  final Color track;
  final double t;
  _DonutPainter(this.slices, this.stroke, this.track, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;
    var start = -math.pi / 2;
    const gap = 0.025;
    for (final s in slices) {
      final sweep = (s.value / total) * math.pi * 2 * t;
      if (sweep > gap) {
        canvas.drawArc(
          rect,
          start,
          sweep - gap,
          false,
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices || old.t != t;
}

/// Barres groupées (ex. revenus vs dépenses par mois).
class PairBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> a;
  final List<double> b;
  final Color colorA;
  final Color colorB;
  final double height;

  const PairBarChart({
    super.key,
    required this.labels,
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = [...a, ...b, 1.0].reduce(math.max);
    final muted = context.appColors.muted;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _bar(a[i] / maxV, colorA),
                        const SizedBox(width: 4),
                        _bar(b[i] / maxV, colorB),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: TextStyle(fontSize: 11, color: muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(double f, Color c) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: f.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => FractionallySizedBox(
        heightFactor: v < 0.01 ? 0.01 : v,
        child: Container(
          width: 14,
          decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
        ),
      ),
    );
  }
}
