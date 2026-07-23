import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'app_info_providers.dart';
import 'app_info_service.dart';

class AppInfoPage extends ConsumerWidget {
  const AppInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(appUsageStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Infos application'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(appUsageStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (stats) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Text(
                          'Espace de stockage utilisé',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stats.formattedSize,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Taille du fichier de base de données sur cet appareil',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Contenu de l\'application', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _StatTile(icon: Icons.account_balance_wallet_outlined, label: 'Comptes', value: stats.accountsCount),
              _StatTile(icon: Icons.swap_vert, label: 'Transactions', value: stats.transactionsCount),
              _StatTile(icon: Icons.handshake_outlined, label: 'Dettes & créances', value: stats.debtsCount),
              _StatTile(icon: Icons.pie_chart_outline, label: 'Budgets', value: stats.budgetsCount),
              _StatTile(icon: Icons.savings_outlined, label: 'Épargnes', value: stats.savingsCount),
              _StatTile(icon: Icons.home_work_outlined, label: 'Biens (Patrimoine)', value: stats.patrimoineItemsCount),
              _StatTile(icon: Icons.request_quote_outlined, label: 'Crédits', value: stats.creditsCount),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '$kAppName — version 0.1.0',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
