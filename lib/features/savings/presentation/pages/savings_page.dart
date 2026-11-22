import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../../core/widgets/panel.dart';
import '../../../../core/widgets/charts.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_error_message.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../domain/entities/savings.dart';
import '../providers/savings_providers.dart';
import '../widgets/savings_movement_dialog.dart';
import '../widgets/savings_form_sheet.dart';
import 'savings_history_page.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/summary_header.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/presentation/providers/summary_providers.dart';

class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savingsAsync = ref.watch(savingsListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Épargne'),
        actions: [
          const AppMenuButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(savingsListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSavingsForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle épargne'),
      ),
      body: savingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(AppErrorMessage.friendly(err))),
        data: (savingsList) {
          if (savingsList.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: savingsList.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Column(children: [
                  _ImmediateSavingsPanel(),
                  SizedBox(height: 8),
                  _SavingsSummaryHeader(),
                ]);
              }
              final savings = savingsList[index - 1];
              return _SavingsCard(savings: savings);
            },
          );
        },
      ),
    );
  }

  void _showSavingsForm(BuildContext context, WidgetRef ref, {Savings? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SavingsFormSheet(existing: existing),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucune épargne pour le moment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Crée une épargne, avec ou sans objectif, reliée à un de tes comptes',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsCard extends ConsumerWidget {
  final Savings savings;

  const _SavingsCard({required this.savings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(allAccountsIncludingArchivedProvider);
    final fmt = AppFormat.currency(symbol: savings.currency, decimalDigits: 0);

    String accountName = '...';
    final accounts = accountsAsync.valueOrNull ?? <Account>[];
    final match = accounts.where((a) => a.id == savings.accountId).toList();
    if (match.isNotEmpty) accountName = match.first.name;

    Color gaugeColor(double ratio) {
      if (ratio >= 1.0) return Colors.green;
      if (ratio >= 0.5) return Colors.orange;
      return Colors.blueGrey;
    }

    return Card(
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => SavingsFormSheet(existing: savings),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      savings.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  Chip(
                    label: Text(accountName),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (savings.hasTarget) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: savings.progress,
                    minHeight: 10,
                    backgroundColor: gaugeColor(savings.progress!).withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(gaugeColor(savings.progress!)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${fmt.format(savings.currentBalance)} sur ${fmt.format(savings.targetAmount ?? 0)}'
                  '${savings.targetDate != null ? ' - avant le ${DateFormat('dd/MM/yyyy').format(savings.targetDate!)}' : ''}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ] else ...[
                Text(
                  'Solde : ${fmt.format(savings.currentBalance)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => SavingsMovementDialog(
                          savings: savings,
                          type: SavingsTransactionType.versement,
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Verser'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => SavingsMovementDialog(
                          savings: savings,
                          type: SavingsTransactionType.retrait,
                        ),
                      ),
                      icon: const Icon(Icons.remove, size: 18),
                      label: const Text('Retirer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SavingsHistoryPage(savings: savings),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Historique'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Bandeau de synthèse : total épargné, objectifs, évolution dans le temps.
class _SavingsSummaryHeader extends ConsumerWidget {
  const _SavingsSummaryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savingsSummaryProvider);
    final colors = context.appColors;
    return async.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text(AppErrorMessage.friendly(e)),
      data: (s) {
        final fmt = AppFormat.currency(symbol: s.currency);
        return SummaryHeader(
          title: 'Synthèse de l’épargne',
          ratio: s.ratio,
          ringColor: colors.info,
          ringText: s.targets > 0 ? null : '—',
          stats: [
            SummaryStat('Total épargné', fmt.format(s.total), color: colors.info),
            SummaryStat('Objectifs cumulés', s.targets > 0 ? fmt.format(s.targets) : 'aucun'),
            SummaryStat('Enveloppes', '${s.count}'),
          ],
          series: s.evolution,
          seriesCaption: 'Évolution de l’épargne',
        );
      },
    );
  }
}


/// Épargne immédiate (Moov) : solde, évolution et opérations récentes.
class _ImmediateSavingsPanel extends ConsumerWidget {
  const _ImmediateSavingsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final async = ref.watch(immediateSavingsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (s) {
        if (s == null) return const SizedBox.shrink();
        final fmt = AppFormat.currency(symbol: s.account.currency);
        return Panel(
          title: 'Épargne immédiate · ${s.account.name}',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fmt.format(s.account.currentBalance), style: amountTextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.info)),
            if (s.evolution.length >= 2) ...[
              const SizedBox(height: 8),
              LineAreaChart(values: s.evolution, color: colors.info, height: 90, grid: false),
            ],
            const SizedBox(height: 10),
            Text('Dernières opérations', style: TextStyle(fontSize: 12, color: colors.muted, fontWeight: FontWeight.w600)),
            if (s.operations.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 6), child: Text('Aucune opération.')),
            for (final t in s.operations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(t.type == TransactionType.revenu ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14, color: t.type == TransactionType.revenu ? colors.positive : colors.negative),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${DateFormat('dd/MM/yyyy').format(t.transactionDate)} · ${(t.description ?? '').isEmpty ? 'Opération' : t.description!}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${t.type == TransactionType.revenu ? '+' : '-'} ${fmt.format(t.amount)}',
                    style: amountTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.type == TransactionType.revenu ? colors.positive : colors.negative),
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
