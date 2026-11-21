import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Logos proposés (choisis dans Paramètres > Affichage).
enum AppLogo { colonnes, gAscendant, anneau, monogramme, hexagone, barres, bouclier, diamant }

extension AppLogoInfo on AppLogo {
  String get label => const [
        'Colonnes',
        'G ascendant',
        'Anneau de suivi',
        'Monogramme GF',
        'Pièce hexagonale',
        'Barres et courbe',
        'Bouclier',
        'Diamant',
      ][index];

  String get hint => const [
        'Le temple de la banque : solidité et confiance',
        'La lettre G traversée par une courbe de croissance',
        'Le cercle qui se remplit, comme tes objectifs',
        'Les deux initiales, sobres et géométriques',
        'Une pièce et une double flèche de progression',
        'Le monde des graphiques et des statistiques',
        'Sécurité et confidentialité des données',
        'Valeur et patrimoine, style plus luxe',
      ][index];
}

class AppLogoController extends StateNotifier<AppLogo> {
  AppLogoController() : super(AppLogo.barres) {
    _load();
  }

  static const _key = 'app_logo';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final i = p.getInt(_key);
      if (i != null && i >= 0 && i < AppLogo.values.length) state = AppLogo.values[i];
    } catch (_) {}
  }

  Future<void> set(AppLogo logo) async {
    state = logo;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_key, logo.index);
    } catch (_) {}
  }
}

final appLogoProvider = StateNotifierProvider<AppLogoController, AppLogo>((ref) => AppLogoController());

/// Dessine un logo aux couleurs du thème actif. Avec `tile`, ajoute un fond
/// carré arrondi façon icône d'application.
class AppLogoMark extends StatelessWidget {
  final AppLogo logo;
  final double size;
  final bool tile;
  const AppLogoMark({super.key, required this.logo, this.size = 28, this.tile = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = CustomPaint(
      size: Size.square(tile ? size * 0.68 : size),
      painter: _LogoPainter(logo, scheme.primary, scheme.onSurface, scheme.surfaceContainerLowest),
    );
    return Semantics(
      label: 'Logo ${logo.label}',
      child: tile
          ? Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(size * 0.23),
                border: Border.all(color: scheme.outline),
              ),
              child: mark,
            )
          : mark,
    );
  }
}

class _LogoPainter extends CustomPainter {
  final AppLogo logo;
  final Color accent, fg, bg;
  _LogoPainter(this.logo, this.accent, this.fg, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    Paint fill(Color c) => Paint()..color = c;
    Paint stroke(Color c, double w, {StrokeCap cap = StrokeCap.round, StrokeJoin join = StrokeJoin.round}) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = cap
      ..strokeJoin = join;
    Path poly(List<List<double>> pts, {bool close = false}) {
      final p = Path()..moveTo(pts.first[0], pts.first[1]);
      for (final q in pts.skip(1)) {
        p.lineTo(q[0], q[1]);
      }
      if (close) p.close();
      return p;
    }

    switch (logo) {
      case AppLogo.colonnes:
        canvas.drawPath(poly([[50, 12], [88, 32], [12, 32]], close: true), fill(accent));
        canvas.drawRect(const Rect.fromLTWH(18, 34, 64, 5), fill(accent));
        for (final x in [24.0, 45.0, 66.0]) {
          canvas.drawRect(Rect.fromLTWH(x, 43, 10, 34), fill(fg));
        }
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 80, 72, 8), const Radius.circular(1)), fill(accent));
        break;
      case AppLogo.gAscendant:
        final g = Path()
          ..moveTo(80, 34)
          ..arcToPoint(const Offset(83, 54), radius: const Radius.circular(33), largeArc: true, clockwise: false)
          ..lineTo(56, 54);
        canvas.drawPath(g, stroke(accent, 10));
        canvas.drawPath(poly([[32, 64], [44, 52], [54, 59], [70, 40]]), stroke(fg, 5));
        break;
      case AppLogo.anneau:
        canvas.drawCircle(const Offset(50, 50), 36, stroke(fg.withValues(alpha: 0.18), 11));
        canvas.drawArc(Rect.fromCircle(center: const Offset(50, 50), radius: 36), -math.pi / 2, math.pi * 2 * 0.7, false, stroke(accent, 11));
        canvas.drawCircle(const Offset(50, 50), 17, fill(accent));
        canvas.drawPath(poly([[42, 54], [50, 46], [58, 54]]), stroke(bg, 5));
        break;
      case AppLogo.monogramme:
        final g = Path()
          ..moveTo(46, 34)
          ..arcToPoint(const Offset(46, 68), radius: const Radius.circular(21), largeArc: true, clockwise: false)
          ..lineTo(46, 53)
          ..lineTo(33, 53);
        canvas.drawPath(g, stroke(accent, 9, cap: StrokeCap.square, join: StrokeJoin.miter));
        final f = Path()
          ..moveTo(63, 28)
          ..lineTo(63, 72)
          ..moveTo(63, 30)
          ..lineTo(86, 30)
          ..moveTo(63, 50)
          ..lineTo(82, 50);
        canvas.drawPath(f, stroke(fg, 9, cap: StrokeCap.square));
        break;
      case AppLogo.hexagone:
        canvas.drawPath(poly([[50, 8], [87, 29], [87, 71], [50, 92], [13, 71], [13, 29]], close: true), fill(accent));
        canvas.drawPath(poly([[33, 50], [50, 33], [67, 50]]), stroke(bg, 8));
        canvas.drawPath(poly([[33, 70], [50, 53], [67, 70]]), stroke(bg.withValues(alpha: 0.45), 8));
        break;
      case AppLogo.barres:
        final bars = [
          [16.0, 60.0, 26.0, 0.55],
          [35.0, 48.0, 38.0, 0.7],
          [54.0, 54.0, 32.0, 0.85],
          [73.0, 36.0, 50.0, 1.0],
        ];
        for (final b in bars) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b[0], b[1], 13, b[2]), const Radius.circular(2)), fill(fg.withValues(alpha: b[3])));
        }
        canvas.drawPath(poly([[20, 46], [41, 32], [60, 40], [80, 16]]), stroke(accent, 6));
        canvas.drawCircle(const Offset(80, 16), 6, fill(accent));
        break;
      case AppLogo.bouclier:
        final s = Path()
          ..moveTo(50, 8)
          ..lineTo(86, 21)
          ..lineTo(86, 48)
          ..cubicTo(86, 69, 69, 84, 50, 93)
          ..cubicTo(31, 84, 14, 69, 14, 48)
          ..lineTo(14, 21)
          ..close();
        canvas.drawPath(s, fill(accent));
        canvas.drawCircle(const Offset(50, 48), 20, fill(bg));
        canvas.drawPath(poly([[39, 48], [47, 56], [62, 39]]), stroke(accent, 7));
        break;
      case AppLogo.diamant:
        canvas.drawPath(poly([[50, 10], [86, 40], [50, 90], [14, 40]], close: true), fill(accent));
        canvas.drawLine(const Offset(14, 40), const Offset(86, 40), stroke(bg, 3));
        canvas.drawPath(poly([[50, 10], [36, 40], [50, 90], [64, 40], [50, 10]]), stroke(bg, 3));
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.logo != logo || old.accent != accent || old.fg != fg || old.bg != bg;
}
