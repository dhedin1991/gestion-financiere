import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_error_message.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/charts.dart';
import '../../../../core/widgets/panel.dart';
import '../../../dashboard/presentation/pages/home_page.dart';
import '../../../dashboard/presentation/providers/insights_providers.dart';
import '../../domain/entities/account.dart';
import '../providers/account_providers.dart';
import '../providers/balance_alerts.dart';

enum AccountsView { cartes, tableau, evolution }

extension on AccountsView {
  String get label => const ['Cartes', 'Tableau', 'Évolution'][index];
  IconData get icon => const [Icons.dashboard_outlined, Icons.table_rows_outlined, Icons.show_chart][index];
}

class AccountsViewController extends StateNotifier<AccountsView> {
  AccountsViewController() : super(AccountsView.cartes) {
    _load();
  }
  static const _key = 'accounts_view';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final i = p.getInt(_key);
      if (i != null && i >= 0 && i < AccountsView.values.length) state = AccountsView.values[i];
    } catch (_) {}
  }

  Future<void> set(AccountsView v) async {
    state = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_key, v.index);
    } catch (_) {}
  }
}

final accountsViewProvider =
    StateNotifierProvider<AccountsViewController, AccountsView>((ref) => AccountsViewController());

/// Corps de la page « Mes comptes » : synthèse, alertes, et trois
/// présentations au choix (cartes avec cercle de suivi, tableau, évolution).
class AccountsOverview extends ConsumerWidget {
  final List<Account> accounts;
  final void Function(Account) onOpen;
  const AccountsOverview({super.key, required this.accounts, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(accountsViewProvider);
    final thresholds = ref.watch(balanceThresholdsProvider);
    final colors = context.appColors;
    final main = ref.watch(mainCurrencyProvider).valueOrNull ?? 'XOF';
    final total = accounts.where((a) => a.currency == main).fold<double>(0, (s, a) => s + a.currentBalance);
    final low = accounts.where((a) => alertLevelFor(a, thresholds) != AlertLevel.ok).toList();
    final fmt = AppFormat.currency(symbol: main, decimalDigits: 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Panel(
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Trésorerie totale ($main)', style: TextStyle(color: colors.muted, fontSize: 12)),
                Text(fmt.format(total), style: amountTextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Comptes actifs', style: TextStyle(color: colors.muted, fontSize: 12)),
                Text('${accounts.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Soldes à surveiller', style: TextStyle(color: colors.muted, fontSize: 12)),
                Text('${low.length}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: low.isEmpty ? colors.positive : colors.negative)),
              ]),
              SegmentedButton<AccountsView>(
                showSelectedIcon: false,
                segments: [
                  for (final v in AccountsView.values) ButtonSegment(value: v, label: Text(v.label), icon: Icon(v.icon, size: 16)),
                ],
                selected: {view},
                onSelectionChanged: (s) => ref.read(accountsViewProvider.notifier).set(s.first),
              ),
            ],
          ),
        ),
        if (low.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.negative.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.negative.withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: colors.negative),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Liquidités faibles : ${low.map((a) => a.name).join(', ')}',
                  style: TextStyle(color: colors.negative, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        const _AccountsCharts(),
        const SizedBox(height: 12),
        switch (view) {
          AccountsView.cartes => _Cards(accounts: accounts, onOpen: onOpen),
          AccountsView.tableau => _Table(accounts: accounts, onOpen: onOpen),
          AccountsView.evolution => const _Evolution(),
        },
        const SizedBox(height: 80),
      ],
    );
  }
}

String _roleLabel(Account a) {
  switch (a.role) {
    case 'caisse':
      return 'Caisse principale';
    case 'epargne':
      return 'Épargne immédiate';
    default:
      return '';
  }
}

class _Cards extends ConsumerWidget {
  final List<Account> accounts;
  final void Function(Account) onOpen;
  const _Cards({required this.accounts, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(accountTrackingProvider).valueOrNull ?? const <AccountTracking>[];
    final thresholds = ref.watch(balanceThresholdsProvider);
    final colors = context.appColors;

    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 1100 ? 3 : (box.maxWidth >= 640 ? 2 : 1);
      const gap = 12.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final a in accounts)
          SizedBox(
            width: w,
            child: Builder(builder: (context) {
              final t = tracking.where((x) => x.history.account.id == a.id).toList();
              final level = alertLevelFor(a, thresholds);
              final color = level == AlertLevel.ok ? Theme.of(context).colorScheme.primary : alertColor(context, level);
              final fmt = AppFormat.currency(symbol: a.currency, decimalDigits: 0);
              final ratio = t.isEmpty ? 0.0 : t.first.ratio;
              final values = t.isEmpty ? const <double>[] : t.first.history.values;
              final up = t.isEmpty ? true : t.first.history.changePct >= 0;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onOpen(a),
                child: Panel(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(_iconFor(a.type), size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      if (_roleLabel(a).isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_roleLabel(a), style: const TextStyle(fontSize: 10)),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      RingGauge(value: ratio, color: color, size: 72, stroke: 9),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(fmt.format(a.currentBalance),
                              style: amountTextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: level == AlertLevel.ok ? Theme.of(context).colorScheme.onSurface : color)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Flexible(child: Text(alertLabel(level), style: TextStyle(fontSize: 11, color: color))),
                          ]),
                          if (t.isNotEmpty)
                            Text(
                              '${up ? '▲ +' : '▼ '}${t.first.history.changePct.toStringAsFixed(1)} % sur la période',
                              style: TextStyle(fontSize: 11, color: up ? colors.positive : colors.negative),
                            ),
                        ]),
                      ),
                    ]),
                    if (values.length > 1) ...[
                      const SizedBox(height: 10),
                      LineAreaChart(values: values, color: color, height: 54, grid: false),
                    ],
                  ]),
                ),
              );
            }),
          ),
      ]);
    });
  }
}

IconData _iconFor(AccountType type) {
  switch (type) {
    case AccountType.courant:
      return Icons.account_balance;
    case AccountType.epargne:
      return Icons.savings;
    case AccountType.mobileMoney:
      return Icons.phone_iphone;
    case AccountType.especes:
      return Icons.payments;
    case AccountType.autre:
      return Icons.wallet;
  }
}

String _typeLabel(AccountType t) =>
    const {'courant': 'Courant', 'epargne': 'Épargne', 'mobileMoney': 'Mobile Money', 'especes': 'Espèces', 'autre': 'Autre'}[t.name] ?? t.name;

class _Table extends ConsumerWidget {
  final List<Account> accounts;
  final void Function(Account) onOpen;
  const _Table({required this.accounts, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thresholds = ref.watch(balanceThresholdsProvider);
    return Panel(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Compte')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Rôle')),
            DataColumn(label: Text('Solde'), numeric: true),
            DataColumn(label: Text('État')),
          ],
          rows: [
            for (final a in accounts)
              () {
                final level = alertLevelFor(a, thresholds);
                final color = alertColor(context, level);
                final fmt = AppFormat.currency(symbol: a.currency, decimalDigits: 0);
                return DataRow(
                  onSelectChanged: (_) => onOpen(a),
                  cells: [
                    DataCell(Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(_typeLabel(a.type))),
                    DataCell(Text(_roleLabel(a))),
                    DataCell(Text(fmt.format(a.currentBalance), style: amountTextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: level == AlertLevel.ok ? Theme.of(context).colorScheme.onSurface : color))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(alertLabel(level), style: TextStyle(color: color, fontSize: 12)),
                    ])),
                  ],
                );
              }(),
          ],
        ),
      ),
    );
  }
}

class _Evolution extends ConsumerWidget {
  const _Evolution();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightRangeProvider);
    final tracking = ref.watch(accountTrackingProvider);
    final thresholds = ref.watch(balanceThresholdsProvider);
    final colors = context.appColors;
    return tracking.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) => Text(AppErrorMessage.friendly(e)),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, children: [
            for (final r in InsightRange.values)
              ChoiceChip(label: Text(r.label), selected: r == range, onSelected: (_) => ref.read(insightRangeProvider.notifier).state = r),
          ]),
          const SizedBox(height: 12),
          Panel(
            title: 'Évolution de chaque compte',
            child: MultiLineChart(
              series: [for (final t in list) t.history.values],
              colors: [for (var i = 0; i < list.length; i++) seriesColor(context, i)],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth >= 1100 ? 3 : (box.maxWidth >= 640 ? 2 : 1);
            const gap = 12.0;
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (var i = 0; i < list.length; i++)
                SizedBox(
                  width: w,
                  child: AccountTrackingCard(
                    tracking: list[i],
                    color: () {
                      final level = alertLevelFor(list[i].history.account, thresholds);
                      return level == AlertLevel.ok ? seriesColor(context, i) : alertColor(context, level);
                    }(),
                    muted: colors.muted,
                  ),
                ),
            ]);
          }),
        ]);
      },
    );
  }
}


/// Graphiques toujours visibles en haut de la page Comptes : répartition des
/// soldes (cercle) et évolution du patrimoine (courbe).
class _AccountsCharts extends ConsumerWidget {
  const _AccountsCharts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final hist = ref.watch(accountHistoriesProvider);
    final series = ref.watch(netWorthSeriesProvider);
    final main = ref.watch(mainCurrencyProvider).valueOrNull ?? 'XOF';

    final donut = Panel(
      title: 'Répartition des soldes',
      child: hist.when(
        loading: () => const SizedBox(height: 130, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (list) {
          final items = list.where((h) => h.account.currency == main && h.last > 0).toList();
          final total = items.fold<double>(0, (a, h) => a + h.last);
          if (items.isEmpty) return const SizedBox(height: 80, child: Center(child: Text('Aucun solde positif')));
          return Row(children: [
            DonutChart(
              size: 120,
              stroke: 15,
              slices: [for (final h in items) DonutSlice(h.last, seriesColor(context, list.indexOf(h)))],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(children: [
                for (final h in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: seriesColor(context, list.indexOf(h)), borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(h.account.name, overflow: TextOverflow.ellipsis)),
                      Text('${(h.last / total * 100).round()} %', style: TextStyle(fontSize: 12, color: colors.muted)),
                    ]),
                  ),
              ]),
            ),
          ]);
        },
      ),
    );

    final curve = Panel(
      title: 'Évolution du patrimoine',
      child: series.when(
        loading: () => const SizedBox(height: 130, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (v) => v.length < 2
            ? const SizedBox(height: 80, child: Center(child: Text('Pas encore assez de données')))
            : LineAreaChart(values: v, color: colors.info, height: 130),
      ),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 800) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: donut),
          const SizedBox(width: 12),
          Expanded(child: curve),
        ]);
      }
      return Column(children: [donut, const SizedBox(height: 12), curve]);
    });
  }
}
