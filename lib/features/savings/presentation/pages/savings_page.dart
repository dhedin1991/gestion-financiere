import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../domain/entities/savings.dart';
import '../providers/savings_providers.dart';
import '../widgets/savings_movement_dialog.dart';
import '../widgets/savings_form_sheet.dart';
import 'savings_history_page.dart';

class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savingsAsync = ref.watch(savingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Épargne'),
        actions: [
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
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (savingsList) {
          if (savingsList.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: savingsList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final savings = savingsList[index];
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
    final accountsAsync = ref.watch(accountsListProvider);
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: savings.currency, decimalDigits: 0);

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
                    backgroundColor: gaugeColor(savings.progress!).withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(gaugeColor(savings.progress!)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${fmt.format(savings.currentBalance)} sur ${fmt.format(savings.targetAmount)}'
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
