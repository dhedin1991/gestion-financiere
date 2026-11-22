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
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../providers/insights_providers.dart';
import '../providers/position_providers.dart';
import 'home_page.dart';

/// Tableau de bord : le mois en un coup d'œil (revenus, dépenses, solde net),
/// la position financière, l'évolution du patrimoine, les flux sur 6 mois,
/// la répartition des dépenses et les dernières transactions.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Tableau de bord'),
        actions: [
          const AppMenuButton(),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(financialPositionProvider);
              ref.invalidate(monthlyIncomeProvider);
              ref.invalidate(monthlyExpenseProvider);
              ref.invalidate(monthlyFlowsProvider);
              ref.invalidate(expenseByCategoryProvider);
              ref.invalidate(netWorthSeriesProvider);
              ref.invalidate(recentTransactionsProvider);
              ref.invalidate(accountsListProvider);
            },
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final left = <Widget>[
          const _MonthKpis(),
          PositionPanel(width: c.maxWidth),
          const _NetWorthPanel(),
        ];
        final right = <Widget>[
          const _FlowsPanel(),
          const _CategoriesPanel(),
          RecentTransactionsPanel(),
        ];
        Widget stack(List<Widget> l) => Column(children: [
              for (final w in l) Padding(padding: const EdgeInsets.only(bottom: 14), child: w),
            ]);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: stack(left)),
                const SizedBox(width: 14),
                Expanded(child: stack(right)),
              ])
            else
              stack([...left, ...right]),
          ],
        );
      }),
    );
  }
}

class _MonthKpis extends ConsumerWidget {
  const _MonthKpis();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final main = ref.watch(mainCurrencyProvider).valueOrNull ?? 'XOF';
    final income = ref.watch(monthlyIncomeProvider).valueOrNull ?? 0;
    final expense = ref.watch(monthlyExpenseProvider).valueOrNull ?? 0;
    final net = income - expense;
    final fmt = AppFormat.currency(symbol: main, decimalDigits: 0);
    final saveRate = income > 0 ? (net / income).clamp(0.0, 1.0).toDouble() : 0.0;

    Widget kpi(String label, double v, Color color) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: colors.muted)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(fmt.format(v), style: amountTextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
        );

    return Panel(
      title: 'Ce mois-ci',
      child: Row(children: [
        RingGauge(value: saveRate, color: net >= 0 ? colors.positive : colors.negative, size: 76, stroke: 9, centerText: '${(saveRate * 100).round()} %'),
        const SizedBox(width: 14),
        kpi('Revenus', income, colors.positive),
        kpi('Dépenses', expense, colors.negative),
        kpi('Solde net', net.abs(), net >= 0 ? colors.positive : colors.negative),
      ]),
    );
  }
}

class _NetWorthPanel extends ConsumerWidget {
  const _NetWorthPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final series = ref.watch(netWorthSeriesProvider);
    return Panel(
      title: 'Évolution du patrimoine',
      child: series.when(
        loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (v) => v.length < 2
            ? const SizedBox(height: 80, child: Center(child: Text('Pas encore assez de données')))
            : LineAreaChart(values: v, color: colors.info, height: 150),
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
}

class _CategoriesPanel extends ConsumerWidget {
  const _CategoriesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final async = ref.watch(expenseByCategoryProvider);
    final main = ref.watch(mainCurrencyProvider).valueOrNull ?? 'XOF';
    return Panel(
      title: 'Dépenses par catégorie',
      child: async.when(
        loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (list) {
          if (list.isEmpty) return const SizedBox(height: 80, child: Center(child: Text('Aucune dépense')));
          final total = list.fold<double>(0, (s, c) => s + c.amount);
          final fmt = AppFormat.currency(symbol: main, decimalDigits: 0);
          Color col(int i) => seriesColor(context, i);
          return Row(children: [
            DonutChart(size: 130, stroke: 16, slices: [for (var i = 0; i < list.length; i++) DonutSlice(list[i].amount, col(i))]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                for (var i = 0; i < list.length && i < 6; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: col(i), borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(list[i].name, overflow: TextOverflow.ellipsis)),
                      Text('${(list[i].amount / total * 100).round()} %', style: TextStyle(fontSize: 12, color: colors.muted)),
                    ]),
                  ),
                const SizedBox(height: 4),
                Text('Total : ${fmt.format(total)}', style: TextStyle(fontSize: 12, color: colors.muted)),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
