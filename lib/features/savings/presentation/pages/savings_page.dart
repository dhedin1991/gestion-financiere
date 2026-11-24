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
import '../../../../core/widgets/classeur.dart';
import '../widgets/savings_category_ui.dart';
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
    final accounts = ref.watch(allAccountsIncludingArchivedProvider).valueOrNull ?? <Account>[];

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
          String accountName(int id) {
            final m = accounts.where((a) => a.id == id);
            return m.isEmpty ? '' : m.first.name;
          }

          final dateFmt = DateFormat('dd/MM/yyyy');
          final entries = [
            for (final sv in savingsList)
              ClasseurEntry(
                id: 's${sv.id}',
                title: sv.name,
                subtitle: accountName(sv.accountId),
                categoryKey: sv.category.name,
                amount: sv.currentBalance,
                currency: sv.currency,
                progress: sv.progress,
                footnote: sv.hasTarget
                    ? 'Objectif ${AppFormat.currency(symbol: sv.currency, decimalDigits: 0).format(sv.targetAmount ?? 0)}'
                        '${sv.targetDate != null ? ' · avant le ${dateFmt.format(sv.targetDate!)}' : ''}'
                    : 'Sans objectif',
                date: sv.createdAt,
                onTap: () => showFicheSheet<void>(
                  context,
                  builder: (_) => _SavingsFiche(savings: sv, accountName: accountName(sv.accountId), pageContext: context),
                ),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              const _ImmediateSavingsPanel(),
              const SizedBox(height: 10),
              const _SavingsSummaryHeader(),
              const SizedBox(height: 14),
              ClasseurBoard(
                storageKey: 'epargne',
                entries: entries,
                categories: kSavingsClasseur,
                searchHint: 'Rechercher une épargne, un compte, une catégorie…',
              ),
            ],
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
              'Crée une épargne, avec ou sans objectif, rangée dans une catégorie et reliée à un de tes comptes',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fiche d'une épargne : progression, informations et toutes les actions
/// (verser, retirer, historique, modifier).
class _SavingsFiche extends StatelessWidget {
  final Savings savings;
  final String accountName;
  final BuildContext pageContext;

  const _SavingsFiche({required this.savings, required this.accountName, required this.pageContext});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cat = savings.category;
    final fmt = AppFormat.currency(symbol: savings.currency, decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final remaining = savings.hasTarget ? (savings.targetAmount! - savings.currentBalance) : null;

    void closeThen(void Function(BuildContext) action) {
      Navigator.of(context).pop();
      if (pageContext.mounted) action(pageContext);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: cat.color.withValues(alpha: 0.16),
              child: Icon(cat.icon, color: cat.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(savings.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(cat.label, style: TextStyle(color: cat.color, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Montant épargné', style: TextStyle(color: colors.muted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(fmt.format(savings.currentBalance), style: amountTextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cat.color)),
              if (savings.hasTarget) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: savings.progress,
                    minHeight: 10,
                    color: savings.progress! >= 1 ? colors.positive : cat.color,
                    backgroundColor: cat.color.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${((savings.progress ?? 0) * 100).round()} % de ${fmt.format(savings.targetAmount ?? 0)}',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          FicheRow(icon: Icons.account_balance_wallet_outlined, label: 'Compte lié', value: accountName.isEmpty ? '—' : accountName),
          FicheRow(icon: Icons.category_outlined, label: 'Catégorie', value: cat.label),
          if (savings.hasTarget && remaining != null)
            FicheRow(
              icon: Icons.flag_outlined,
              label: 'Reste à épargner',
              value: remaining > 0 ? fmt.format(remaining) : 'Objectif atteint',
            ),
          if (savings.targetDate != null)
            FicheRow(icon: Icons.event_outlined, label: 'Date cible', value: dateFmt.format(savings.targetDate!)),
          FicheRow(icon: Icons.add_circle_outline, label: 'Créée le', value: dateFmt.format(savings.createdAt)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => closeThen((c) => showDialog(
                      context: c,
                      builder: (_) => SavingsMovementDialog(savings: savings, type: SavingsTransactionType.versement),
                    )),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Verser'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => closeThen((c) => showDialog(
                      context: c,
                      builder: (_) => SavingsMovementDialog(savings: savings, type: SavingsTransactionType.retrait),
                    )),
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('Retirer'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => closeThen((c) => Navigator.of(c).push(
                      MaterialPageRoute(builder: (_) => SavingsHistoryPage(savings: savings)),
                    )),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Historique'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => closeThen((c) => showModalBottomSheet(
                      context: c,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => SavingsFormSheet(existing: savings),
                    )),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifier'),
              ),
            ),
          ]),
        ]),
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
