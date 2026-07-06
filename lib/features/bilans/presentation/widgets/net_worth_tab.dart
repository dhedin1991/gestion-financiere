import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/net_worth_snapshot.dart';
import '../providers/bilan_providers.dart';

class NetWorthTab extends ConsumerWidget {
  const NetWorthTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(netWorthHistoryProvider);
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err')),
      data: (history) {
        if (history.isEmpty) {
          return const Center(child: Text('Aucune donnée disponible pour le moment'));
        }

        final latest = history.last;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patrimoine net actuel',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmt.format(latest.netWorth),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Répartition actuelle', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: _BreakdownChart(latest: latest),
              ),
              const SizedBox(height: 12),
              _BreakdownLegend(latest: latest, fmt: fmt),
              const SizedBox(height: 32),
              Text('Évolution dans le temps', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (history.length < 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Pas encore assez d\'historique pour tracer une courbe. '
                    'Une nouvelle photo de ton patrimoine est enregistrée chaque jour '
                    'où tu ouvres cet écran — reviens dans quelques jours !',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                SizedBox(
                  height: 220,
                  child: _EvolutionChart(history: history),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownChart extends StatelessWidget {
  final NetWorthSnapshot latest;

  const _BreakdownChart({required this.latest});

  @override
  Widget build(BuildContext context) {
    final items = <_BreakdownItem>[
      _BreakdownItem('Comptes', latest.totalAccounts, Colors.blue),
      _BreakdownItem('Épargne', latest.totalSavings, Colors.teal),
      _BreakdownItem('Patrimoine', latest.totalPatrimoine, Colors.orange),
      _BreakdownItem('Créances', latest.totalReceivables, Colors.purple),
      _BreakdownItem('Dettes', -latest.totalDebts, Colors.red),
      _BreakdownItem('Crédits restants', -latest.totalCreditsRemaining, Colors.brown),
    ];

    final maxAbs = items.map((i) => i.value.abs()).fold<double>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxAbs == 0 ? 1.0 : maxAbs * 1.2,
        minY: -(maxAbs == 0 ? 1.0 : maxAbs * 1.2),
        barGroups: [
          for (int i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: items[i].value,
                  color: items[i].color,
                  width: 22,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= items.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    items[index].label,
                    style: const TextStyle(fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }
}

class _BreakdownItem {
  final String label;
  final double value;
  final Color color;

  const _BreakdownItem(this.label, this.value, this.color);
}

class _BreakdownLegend extends StatelessWidget {
  final NetWorthSnapshot latest;
  final NumberFormat fmt;

  const _BreakdownLegend({required this.latest, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final items = <_BreakdownItem>[
      _BreakdownItem('Comptes', latest.totalAccounts, Colors.blue),
      _BreakdownItem('Épargne', latest.totalSavings, Colors.teal),
      _BreakdownItem('Patrimoine', latest.totalPatrimoine, Colors.orange),
      _BreakdownItem('Créances', latest.totalReceivables, Colors.purple),
      _BreakdownItem('Dettes', -latest.totalDebts, Colors.red),
      _BreakdownItem('Crédits restants', -latest.totalCreditsRemaining, Colors.brown),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('${item.label} : ${fmt.format(item.value)}', style: const TextStyle(fontSize: 12)),
          ],
        );
      }).toList(),
    );
  }
}

class _EvolutionChart extends StatelessWidget {
  final List<NetWorthSnapshot> history;

  const _EvolutionChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (int i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i].netWorth),
    ];

    final values = history.map((h) => h.netWorth);
    final minY = values.fold<double>(double.infinity, (a, b) => a < b ? a : b);
    final maxY = values.fold<double>(double.negativeInfinity, (a, b) => a > b ? a : b);
    final padding = (maxY - minY).abs() * 0.1;

    return LineChart(
      LineChartData(
        minY: minY - (padding == 0 ? 1 : padding),
        maxY: maxY + (padding == 0 ? 1 : padding),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= history.length) return const SizedBox.shrink();
                // N'affiche qu'une partie des dates pour ne pas surcharger l'axe.
                if (history.length > 6 && index % (history.length ~/ 6).clamp(1, 100) != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('dd/MM').format(history[index].snapshotDate),
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }
}
