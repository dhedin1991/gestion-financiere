import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';

/// Page listant tous les éléments archivés de l'application. Pour l'instant,
/// seul le module Comptes gère l'archivage — les autres modules (Épargne,
/// Dettes...) seront ajoutés ici au fur et à mesure qu'ils prendront en
/// charge l'archivage plutôt que la suppression directe.
class ArchivesPage extends ConsumerWidget {
  const ArchivesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAccountsAsync = ref.watch(archivedAccountsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archives'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(archivedAccountsListProvider),
          ),
        ],
      ),
      body: archivedAccountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const _EmptyState();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Comptes archivés',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Ces comptes ne sont plus affichés dans la liste principale, mais '
                'toutes leurs données (transactions, dettes, épargne liées) sont conservées.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...accounts.map((account) => _ArchivedAccountTile(account: account)),
            ],
          );
        },
      ),
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
            Icon(Icons.archive_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucun élément archivé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Les comptes archivés (contenant des données liées) apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedAccountTile extends ConsumerWidget {
  final Account account;

  const _ArchivedAccountTile({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: account.currency, decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
        title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Solde : ${fmt.format(account.currentBalance)}'),
        trailing: TextButton.icon(
          onPressed: () => _confirmRestore(context, ref),
          icon: const Icon(Icons.unarchive_outlined, size: 18),
          label: const Text('Restaurer'),
        ),
      ),
    );
  }

  void _confirmRestore(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurer ce compte ?'),
        content: Text(
          'Le compte "${account.name}" réapparaîtra dans la liste principale de tes comptes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && account.id != null) {
        try {
          await ref.read(accountActionsProvider).unarchive(account.id!);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Compte restauré')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur : $e')),
            );
          }
        }
      }
    });
  }
}
