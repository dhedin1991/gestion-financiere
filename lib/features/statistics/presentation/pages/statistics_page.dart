import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_error_message.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/charts.dart';
import '../../../../core/widgets/panel.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../dashboard/presentation/pages/home_page.dart';
import '../../../dashboard/presentation/providers/insights_providers.dart';

/// Page **Statistiques** : répartition des dépenses, revenus vs dépenses,
/// évolution de chaque compte et cercles de suivi.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightRangeProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Statistiques'),
        actions: const [AppMenuButton()],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth - 32;
          final wide = w >= 900;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: SegmentedChips<InsightRange>(
                  values: InsightRange.values,
                  selected: range,
                  labelOf: (r) => r.label,
                  onChanged: (r) => ref.read(insightRangeProvider.notifier).state = r,
                ),
              ),
              const SizedBox(height: 12),
              if (wide)
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _CategoriesPanel()),
                    SizedBox(width: 12),
                    Expanded(child: _FlowsPanel()),
                  ],
                )
              else ...const [
                _CategoriesPanel(),
                SizedBox(height: 12),
                _FlowsPanel(),
              ],
              const SizedBox(height: 12),
              const _AccountsLinesPanel(),
              const SizedBox(height: 12),
              _TrackingPanel(width: w),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _CategoriesPanel extends ConsumerWidget {
  const _CategoriesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final slices = ref.watch(expenseByCategoryProvider);
    final main = ref.watch(mainCurrencyProvider).valueOrNull ?? 'XOF';
    final fmt = AppFormat.currency(symbol: main);
    return Panel(
      title: 'Dépenses par catégorie (ce mois)',
      child: slices.when(
        loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (list) {
          if (list.isEmpty) return const SizedBox(height: 90, child: Center(child: Text('Aucune dépense ce mois-ci')));
          final total = list.fold<double>(0, (a, s) => a + s.amount);
          Color colorOf(int i) => list[i].color != null ? Color(list[i].color!).withValues(alpha: 1) : seriesColor(context, i);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonutChart(
                size: 150,
                stroke: 18,
                slices: [for (var i = 0; i < list.length; i++) DonutSlice(list[i].amount, colorOf(i))],
                center: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Total', style: TextStyle(fontSize: 11, color: colors.muted)),
                  Text(fmt.format(total), style: amountTextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(children: [
                  for (var i = 0; i < list.length && i < 8; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: colorOf(i), borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(list[i].name, overflow: TextOverflow.ellipsis)),
                        Text('${(list[i].amount / total * 100).round()} %', style: amountTextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.muted)),
                      ]),
                    ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FlowsPanel extends ConsumerWidget {
  const _FlowsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final flows = ref.watch(monthlyFlowsProvider);
    return Panel(
      title: 'Revenus et dépenses (6 mois)',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _dot(colors.positive), const SizedBox(width: 4), Text('Revenus', style: TextStyle(fontSize: 12, color: colors.muted)),
        const SizedBox(width: 10),
        _dot(colors.negative), const SizedBox(width: 4), Text('Dépenses', style: TextStyle(fontSize: 12, color: colors.muted)),
      ]),
      child: flows.when(
        loading: () => const SizedBox(height: 170, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (list) => PairBarChart(
          labels: [for (final f in list) f.label],
          a: [for (final f in list) f.income],
          b: [for (final f in list) f.expense],
          colorA: colors.positive,
          colorB: colors.negative,
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
}

class _AccountsLinesPanel extends ConsumerWidget {
  const _AccountsLinesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final hist = ref.watch(accountHistoriesProvider);
    return Panel(
      title: 'Évolution de chaque compte',
      child: hist.when(
        loading: () => const SizedBox(height: 170, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (list) {
          if (list.isEmpty) return const SizedBox(height: 80, child: Center(child: Text('Aucun compte')));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 16, runSpacing: 6, children: [
                for (var i = 0; i < list.length; i++)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 14, height: 3, decoration: BoxDecoration(color: seriesColor(context, i), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text(list[i].account.name, style: TextStyle(fontSize: 12, color: colors.muted)),
                  ]),
              ]),
              const SizedBox(height: 10),
              MultiLineChart(
                series: [for (final h in list) h.values],
                colors: [for (var i = 0; i < list.length; i++) seriesColor(context, i)],
              ),
              const SizedBox(height: 4),
              Text('Chaque courbe est mise à l’échelle de son propre compte pour comparer les tendances.',
                  style: TextStyle(fontSize: 11, color: colors.muted)),
            ],
          );
        },
      ),
    );
  }
}

class _TrackingPanel extends ConsumerWidget {
  final double width;
  const _TrackingPanel({required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final tracking = ref.watch(accountTrackingProvider);
    return Panel(
      title: 'Suivi des comptes (objectifs)',
      child: tracking.when(
        loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (list) {
          if (list.isEmpty) return const Text('Aucun compte');
          final cols = width >= 1000 ? 4 : (width >= 640 ? 2 : 1);
          return gridOf(width - 32, cols, [
            for (var i = 0; i < list.length; i++)
              Row(children: [
                RingGauge(value: list[i].ratio, color: seriesColor(context, i), size: 78, stroke: 9),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(list[i].history.account.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                    Text(
                      '${AppFormat.currency(symbol: list[i].history.account.currency).format(list[i].history.last)}\nsur ${AppFormat.amount(list[i].goal)}',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                  ]),
                ),
              ]),
          ]);
        },
      ),
    );
  }
}
