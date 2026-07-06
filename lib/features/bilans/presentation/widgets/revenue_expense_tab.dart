import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bilan_providers.dart';

class RevenueExpenseTab extends ConsumerStatefulWidget {
  const RevenueExpenseTab({super.key});

  @override
  ConsumerState<RevenueExpenseTab> createState() => _RevenueExpenseTabState();
}

class _RevenueExpenseTabState extends ConsumerState<RevenueExpenseTab> {
  BilanPeriod _period = BilanPeriod.mensuel;

  String _periodLabel(BilanPeriod period) {
    switch (period) {
      case BilanPeriod.journalier:
        return 'Jour';
      case BilanPeriod.hebdomadaire:
        return 'Semaine';
      case BilanPeriod.mensuel:
        return 'Mois';
      case BilanPeriod.trimestriel:
        return 'Trimestre';
      case BilanPeriod.semestriel:
        return 'Semestre';
      case BilanPeriod.annuel:
        return 'Année';
    }
  }

  String _periodShortDate(DateTime date, BilanPeriod period) {
    switch (period) {
      case BilanPeriod.journalier:
        return DateFormat('dd/MM').format(date);
      case BilanPeriod.hebdomadaire:
        return DateFormat('dd/MM').format(date);
      case BilanPeriod.mensuel:
        return DateFormat('MMM', 'fr_FR').format(date);
      case BilanPeriod.trimestriel:
        return 'T${((date.month - 1) ~/ 3) + 1} ${date.year}';
      case BilanPeriod.semestriel:
        return 'S${date.month <= 6 ? 1 : 2} ${date.year}';
      case BilanPeriod.annuel:
        return date.year.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = BilanQuery(period: _period, periodsCount: 6);
    final summaryAsync = ref.watch(revenueExpenseSummaryProvider(query));
    final fmt = NumberFormat.compactCurrency(locale: 'fr_FR', symbol: 'XOF');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<BilanPeriod>(
            value: _period,
            decoration: const InputDecoration(
              labelText: 'Regrouper par',
              border: OutlineInputBorder(),
            ),
            items: BilanPeriod.values.map((p) {
              return DropdownMenuItem(value: p, child: Text(_periodLabel(p)));
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _period = value);
            },
          ),
        ),
        Expanded(
          child: summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Erreur : $err')),
            data: (periods) {
              if (periods.isEmpty || periods.every((p) => p.totalRevenue == 0 && p.totalExpense == 0)) {
                return const Center(child: Text('Aucune transaction sur cette période'));
              }

              final maxY = periods
                  .map((p) => p.totalRevenue > p.totalExpense ? p.totalRevenue : p.totalExpense)
                  .fold<double>(0, (a, b) => a > b ? a : b);

              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                child: BarChart(
                  BarChartData(
                    maxY: maxY == 0 ? 1.0 : maxY * 1.2,
                    barGroups: [
                      for (int i = 0; i < periods.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: periods[i].totalRevenue,
                              color: Colors.green,
                              width: 10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              toY: periods[i].totalExpense,
                              color: Colors.red,
                              width: 10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) => Text(
                            fmt.format(value),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= periods.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _periodShortDate(periods[index].periodStart, _period),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.green, label: 'Revenus'),
              const SizedBox(width: 24),
              _LegendDot(color: Colors.red, label: 'Dépenses'),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
