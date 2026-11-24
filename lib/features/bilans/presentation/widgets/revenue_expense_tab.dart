import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_error_message.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/chart_style.dart';
import '../../../../core/widgets/panel.dart';
import '../../../../core/widgets/summary_header.dart';
import '../providers/bilan_providers.dart';
import '../../../../core/utils/app_format.dart';

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
    final fmt = AppFormat.compactCurrency(symbol: 'XOF');
    final full = AppFormat.currency(symbol: 'XOF');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in BilanPeriod.values)
              ChoiceChip(
                label: Text(_periodLabel(p)),
                selected: p == _period,
                onSelected: (_) => setState(() => _period = p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        summaryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Center(child: Text(AppErrorMessage.friendly(err))),
          data: (periods) {
            if (periods.isEmpty || periods.every((p) => p.totalRevenue == 0 && p.totalExpense == 0)) {
              return const EmptyState(
                icon: Icons.bar_chart,
                message: 'Aucune transaction sur cette période',
              );
            }
            final totalRev = periods.fold<double>(0, (a, p) => a + p.totalRevenue);
            final totalExp = periods.fold<double>(0, (a, p) => a + p.totalExpense);
            final net = totalRev - totalExp;
            final maxY = periods
                .map((p) => p.totalRevenue > p.totalExpense ? p.totalRevenue : p.totalExpense)
                .fold<double>(0, (a, b) => a > b ? a : b);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SummaryHeader(
                  title: 'Synthèse des 6 dernières périodes',
                  ratio: totalRev <= 0 ? 0 : (net / totalRev).clamp(0.0, 1.0),
                  ringColor: net >= 0 ? context.appColors.positive : context.appColors.negative,
                  ringText: totalRev <= 0 ? '—' : '${(net / totalRev * 100).round()}%',
                  stats: [
                    SummaryStat('Revenus', full.format(totalRev), color: context.appColors.positive),
                    SummaryStat('Dépenses', full.format(totalExp), color: context.appColors.negative),
                    SummaryStat('Résultat', full.format(net), color: net >= 0 ? context.appColors.positive : context.appColors.negative),
                  ],
                ),
                const SizedBox(height: 12),
                Panel(
                  title: 'Revenus et dépenses',
                  child: Column(children: [
                    SizedBox(
                      height: 240,
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
                                    color: context.appColors.positive,
                                    width: 10,
                                    borderRadius: context.chartStyle.barRadius(10),
                                  ),
                                  BarChartRodData(
                                    toY: periods[i].totalExpense,
                                    color: context.appColors.negative,
                                    width: 10,
                                    borderRadius: context.chartStyle.barRadius(10),
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
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegendDot(color: context.appColors.positive, label: 'Revenus'),
                        const SizedBox(width: 24),
                        _LegendDot(color: context.appColors.negative, label: 'Dépenses'),
                      ],
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Panel(
                  title: 'Détail par période',
                  child: Column(children: [
                    for (final p in periods)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          SizedBox(
                            width: 70,
                            child: Text(_periodShortDate(p.periodStart, _period),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            child: Text('+ ${fmt.format(p.totalRevenue)}',
                                style: TextStyle(color: context.appColors.positive, fontSize: 12)),
                          ),
                          Expanded(
                            child: Text('- ${fmt.format(p.totalExpense)}',
                                style: TextStyle(color: context.appColors.negative, fontSize: 12)),
                          ),
                          Text(fmt.format(p.totalRevenue - p.totalExpense),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ]),
                      ),
                  ]),
                ),
              ],
            );
          },
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
