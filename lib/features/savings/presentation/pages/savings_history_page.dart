import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/savings.dart';
import '../providers/savings_providers.dart';

class SavingsHistoryPage extends ConsumerWidget {
  final Savings savings;
  const SavingsHistoryPage({super.key, required this.savings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(savingsTransactionsProvider(savings.id!));
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: savings.currency, decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: Text('Historique - ${savings.name}')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('Aucun mouvement enregistré'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = transactions[index];
              final isVersement = t.type == SavingsTransactionType.versement;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isVersement ? Colors.green : Colors.red).withOpacity(0.15),
                  child: Icon(
                    isVersement ? Icons.add : Icons.remove,
                    color: isVersement ? Colors.green : Colors.red,
                  ),
                ),
                title: Text('${isVersement ? '+' : '-'}${fmt.format(t.amount)}'),
                subtitle: Text(
                  '${DateFormat('dd/MM/yyyy').format(t.date)}'
                  '${t.note != null && t.note!.isNotEmpty ? ' - ${t.note}' : ''}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Supprimer ce mouvement ?'),
                        content: const Text('Le solde de l\'épargne et du compte lié seront ajustés.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(savingsActionsProvider).deleteTransaction(t.id!, savings.id!);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
