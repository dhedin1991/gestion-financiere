import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'charts.dart';
import 'panel.dart';

/// Une statistique du bandeau de synthèse.
class SummaryStat {
  final String label;
  final String value;
  final Color? color;
  const SummaryStat(this.label, this.value, {this.color});
}

/// Bandeau de synthèse commun aux pages Épargne, Crédits et Dettes :
/// cercle de suivi animé, chiffres clés et courbe d'évolution optionnelle.
class SummaryHeader extends StatelessWidget {
  final String title;
  final double ratio;
  final Color ringColor;
  final String? ringText;
  final List<SummaryStat> stats;
  final List<double>? series;
  final String? seriesCaption;

  const SummaryHeader({
    super.key,
    required this.title,
    required this.ratio,
    required this.ringColor,
    required this.stats,
    this.ringText,
    this.series,
    this.seriesCaption,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Panel(
      title: title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RingGauge(value: ratio, color: ringColor, size: 84, stroke: 9, centerText: ringText),
          const SizedBox(width: 16),
          Expanded(
            child: Column(children: [
              for (final s in stats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(s.label, style: TextStyle(fontSize: 12, color: colors.muted))),
                    Text(
                      s.value,
                      style: amountTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: s.color ?? Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ]),
        if (series != null && series!.length >= 2) ...[
          const SizedBox(height: 12),
          if (seriesCaption != null) Text(seriesCaption!, style: TextStyle(fontSize: 11, color: colors.muted)),
          const SizedBox(height: 4),
          LineAreaChart(values: series!, color: ringColor, height: 70, grid: false),
        ],
      ]),
    );
  }
}
