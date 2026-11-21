import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/display/display_prefs.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_error_message.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/charts.dart';
import '../../../../core/widgets/panel.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../savings/presentation/providers/savings_providers.dart';
import '../../../settings/presentation/providers/exchange_rate_providers.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../providers/insights_providers.dart';

/// Couleurs des séries (comptes) : fixes pour un compte donné, lisibles sur
/// tous les thèmes.
Color seriesColor(BuildContext context, int index) {
  final c = context.appColors;
  final palette = [c.info, c.positive, const Color(0xFF8E7CF0), Theme.of(context).colorScheme.primary, c.warning, const Color(0xFF2EC4B6)];
  return palette[index % palette.length];
}

/// Dispose des enfants en grille de `cols` colonnes (largeur disponible `w`).
Widget gridOf(double w, int cols, List<Widget> children, {double gap = 12}) {
  final itemW = (w - gap * (cols - 1)) / cols;
  return Wrap(
    spacing: gap,
    runSpacing: gap,
    children: [for (final c in children) SizedBox(width: itemW, child: c)],
  );
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(displayPrefsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Accueil'),
        actions: [
          IconButton(
            tooltip: prefs.hideAmounts ? 'Afficher les montants' : 'Masquer les montants',
            icon: Icon(prefs.hideAmounts ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => ref.read(displayPrefsProvider.notifier).toggleHideAmounts(),
          ),
          const AppMenuButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsListProvider);
          ref.invalidate(accountHistoriesProvider);
          ref.invalidate(ringMetricsProvider);
        },
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth - 32;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Greeting(),
                const SizedBox(height: 14),
                _Kpis(width: w),
                const SizedBox(height: 14),
                _ChartsRow(width: w),
                const SizedBox(height: 14),
                _Rings(width: w),
                const SizedBox(height: 14),
                _AccountCards(width: w),
                const SizedBox(height: 14),
                _ConvertedNote(),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightRangeProvider);
    final date = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now());
    final muted = context.appColors.muted;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bonjour', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            Text(date, style: TextStyle(color: muted)),
          ],
        ),
        SegmentedChips<InsightRange>(
          values: InsightRange.values,
          selected: range,
          labelOf: (r) => r.label,
          onChanged: (r) => ref.read(insightRangeProvider.notifier).state = r,
        ),
      ],
    );
  }
}

class _Kpis extends ConsumerWidget {
  final double width;
  const _Kpis({required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final main = ref.watch(mainCurrencyProvider).valueOrNull ?? 'XOF';
    final fmt = AppFormat.currency(symbol: main);
    final balance = ref.watch(globalBalanceProvider).valueOrNull;
    final income = ref.watch(monthlyIncomeProvider).valueOrNull;
    final expense = ref.watch(monthlyExpenseProvider).valueOrNull;
    final savings = ref.watch(savingsListProvider).valueOrNull;
    final saved = savings?.where((s) => s.currency == main).fold<double>(0, (a, s) => a + s.currentBalance);

    Widget kpi(String label, double? v, Color color, IconData icon, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Panel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: colors.muted))),
              ]),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  v == null ? '…' : fmt.format(v),
                  style: amountTextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cols = width >= 900 ? 4 : 2;
    return gridOf(width, cols, [
      kpi('Solde total', balance, Theme.of(context).colorScheme.primary, Icons.account_balance_wallet_outlined, () => context.go('/accounts')),
      kpi('Revenus du mois', income, colors.positive, Icons.arrow_upward, () => context.go('/transactions')),
      kpi('Dépenses du mois', expense, colors.negative, Icons.arrow_downward, () => context.go('/transactions')),
      kpi('Épargne cumulée', saved, colors.info, Icons.savings_outlined, () => context.go('/savings')),
    ]);
  }
}

class _ChartsRow extends ConsumerWidget {
  final double width;
  const _ChartsRow({required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final net = ref.watch(netWorthSeriesProvider);
    final hist = ref.watch(accountHistoriesProvider);
    final main = ref.watch(mainCurrencyProvider).valueOrNull ?? 'XOF';
    final fmt = AppFormat.currency(symbol: main);

    final netPanel = Panel(
      title: 'Patrimoine net',
      child: net.when(
        loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (v) {
          if (v.length < 2) return const SizedBox(height: 80, child: Center(child: Text('Pas encore assez de données')));
          final change = v.first.abs() < 1e-9 ? 0.0 : (v.last - v.first) / v.first.abs() * 100;
          final up = change >= 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 12,
                children: [
                  Text(fmt.format(v.last), style: amountTextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                  Text(
                    '${up ? '▲ +' : '▼ '}${change.toStringAsFixed(1)} %',
                    style: amountTextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: up ? colors.positive : colors.negative),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LineAreaChart(values: v, color: colors.info, height: 150),
            ],
          );
        },
      ),
    );

    final donut = Panel(
      title: 'Répartition par compte',
      child: hist.when(
        loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (list) {
          final items = list.where((h) => h.account.currency == main && h.last > 0).toList();
          final total = items.fold<double>(0, (a, h) => a + h.last);
          if (items.isEmpty) return const SizedBox(height: 80, child: Center(child: Text('Aucun solde positif')));
          return Row(
            children: [
              DonutChart(
                size: 130,
                stroke: 16,
                slices: [for (var i = 0; i < items.length; i++) DonutSlice(items[i].last, seriesColor(context, list.indexOf(items[i])))],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final h in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: seriesColor(context, list.indexOf(h)), borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(h.account.name, overflow: TextOverflow.ellipsis)),
                          Text('${(h.last / total * 100).round()} %', style: amountTextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.muted)),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (width >= 900) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: netPanel),
          const SizedBox(width: 12),
          Expanded(child: donut),
        ],
      );
    }
    return Column(children: [netPanel, const SizedBox(height: 12), donut]);
  }
}

class _Rings extends ConsumerWidget {
  final double width;
  const _Rings({required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final metrics = ref.watch(ringMetricsProvider);
    final ringColors = [colors.warning, colors.positive, colors.info, const Color(0xFF8E7CF0), Theme.of(context).colorScheme.primary];
    return Panel(
      title: 'Suivi des objectifs',
      child: metrics.when(
        loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (list) {
          final cols = width >= 1000 ? 5 : (width >= 640 ? 3 : 2);
          return gridOf(width - 32, cols, [
            for (var i = 0; i < list.length; i++)
              Row(
                children: [
                  RingGauge(value: list[i].ratio, color: ringColors[i % ringColors.length], size: 78, stroke: 9),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list[i].label, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(list[i].detail, style: TextStyle(fontSize: 12, color: colors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
          ]);
        },
      ),
    );
  }
}

class _AccountCards extends ConsumerWidget {
  final double width;
  const _AccountCards({required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final tracking = ref.watch(accountTrackingProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Évolution de chaque compte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => context.go('/statistics'), child: const Text('Statistiques')),
          ],
        ),
        const SizedBox(height: 6),
        tracking.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text(AppErrorMessage.friendly(e)),
          data: (list) {
            if (list.isEmpty) {
              return Panel(
                child: Row(children: [
                  const Expanded(child: Text('Aucun compte pour l’instant.')),
                  FilledButton(onPressed: () => context.go('/accounts'), child: const Text('Créer un compte')),
                ]),
              );
            }
            final cols = width >= 1100 ? 4 : (width >= 640 ? 2 : 1);
            return gridOf(width, cols, [
              for (var i = 0; i < list.length; i++)
                AccountTrackingCard(tracking: list[i], color: seriesColor(context, i), muted: colors.muted),
            ]);
          },
        ),
      ],
    );
  }
}

/// Carte d'un compte : solde, variation, courbe propre et cercle de suivi.
class AccountTrackingCard extends ConsumerWidget {
  final AccountTracking tracking;
  final Color color;
  final Color muted;
  const AccountTrackingCard({super.key, required this.tracking, required this.color, required this.muted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = tracking.history;
    final colors = context.appColors;
    final fmt = AppFormat.currency(symbol: h.account.currency);
    final up = h.changePct >= 0;
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(h.account.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            Text(h.account.currency, style: TextStyle(fontSize: 11, color: muted)),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
            Text(fmt.format(h.account.currentBalance), style: amountTextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            Text(
              '${up ? '▲ +' : '▼ '}${h.changePct.toStringAsFixed(1)} %',
              style: amountTextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: up ? colors.positive : colors.negative),
            ),
          ]),
          const SizedBox(height: 8),
          LineAreaChart(values: h.values, color: up ? colors.positive : colors.negative, height: 70, grid: false),
          const Divider(height: 20),
          InkWell(
            onTap: () => _editGoal(context, ref),
            child: Row(children: [
              RingGauge(value: tracking.ratio, color: color, size: 52, stroke: 7, centerStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Suivi de l’objectif', style: TextStyle(fontSize: 12)),
                  Text(
                    tracking.goal > 0
                        ? '${fmt.format(h.last)} sur ${fmt.format(tracking.goal)}${tracking.customGoal ? '' : ' (auto)'}'
                        : 'Touchez pour fixer un objectif',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ]),
              ),
              Icon(Icons.edit_outlined, size: 16, color: muted),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: tracking.customGoal ? tracking.goal.round().toString() : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Objectif — ${tracking.history.account.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Solde visé (${tracking.history.account.currency})', helperText: 'Laissez vide pour un objectif automatique'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    final value = double.tryParse(result.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.'));
    await AccountGoals.write(tracking.history.account.id!, (value == null || value <= 0) ? null : value);
    ref.invalidate(accountTrackingProvider);
  }
}

class _ConvertedNote extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final converted = ref.watch(convertedGlobalBalanceProvider).valueOrNull;
    final missing = ref.watch(missingRatesProvider).valueOrNull ?? const <String>[];
    if (converted == null) return const SizedBox.shrink();
    final fmt = AppFormat.currency(symbol: 'XOF');
    return Panel(
      child: Row(children: [
        Icon(Icons.currency_exchange, size: 18, color: context.appColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Solde estimé toutes devises : ${fmt.format(converted)}'
            '${missing.isEmpty ? '' : ' (taux manquant : ${missing.join(', ')})'}',
          ),
        ),
        TextButton(onPressed: () => context.push('/exchange-rates'), child: const Text('Taux')),
      ]),
    );
  }
}

/// Raccourcis d'écriture utilisés par l'Accueil, le bouton « + » et la recherche.
void openNewTransaction(BuildContext context) => showTransactionFormSheet(context);
