import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../accounts/presentation/widgets/account_card.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../../core/theme/app_theme.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalBalanceAsync = ref.watch(globalBalanceProvider);
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppMenuButton(),
        title: const Text('Tableau de bord'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(globalBalanceProvider);
          ref.invalidate(accountsListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _GlobalBalanceCard(balanceAsync: globalBalanceAsync),
            const SizedBox(height: 16),
            const _MonthlyIncomeExpenseRow(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mes comptes', style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () => context.push('/accounts'),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            accountsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Erreur : $err'),
              data: (accounts) {
                if (accounts.isEmpty) {
                  return _DashboardEmptyState(
                    onAddAccount: () => context.push('/accounts'),
                  );
                }
                final preview = accounts.take(3).toList();
                return Column(
                  children: preview
                      .map((a) => AccountCard(
                            account: a,
                            onTap: () => context.push('/accounts'),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyIncomeExpenseRow extends ConsumerWidget {
  const _MonthlyIncomeExpenseRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(monthlyIncomeProvider);
    final expenseAsync = ref.watch(monthlyExpenseProvider);
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

    Widget buildTile(String label, AsyncValue<double> asyncValue, Color color, IconData icon) {
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                asyncValue.when(
                  loading: () => const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (e, _) => const Text('—'),
                  data: (value) => Text(
                    formatter.format(value),
                    style: amountTextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildTile('Revenus (mois)', incomeAsync, const Color(0xFF16A085), Icons.arrow_downward),
        const SizedBox(width: 12),
        buildTile('Dépenses (mois)', expenseAsync, const Color(0xFFE74C3C), Icons.arrow_upward),
      ],
    );
  }
}

class _GlobalBalanceCard extends StatelessWidget {
  final AsyncValue<double> balanceAsync;
  const _GlobalBalanceCard({required this.balanceAsync});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, const Color(0xFF16A085)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Solde global', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          balanceAsync.when(
            loading: () => const SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            error: (err, _) => const Text('—', style: TextStyle(color: Colors.white, fontSize: 32)),
            data: (balance) => Semantics(
              label: 'Solde total : ${formatter.format(balance)}',
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: balance),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => ExcludeSemantics(
                  child: Text(
                    formatter.format(value),
                    style: amountTextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  final VoidCallback onAddAccount;
  const _DashboardEmptyState({required this.onAddAccount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Commence par ajouter ton premier compte 👇'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAddAccount,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un compte'),
            ),
          ],
        ),
      ),
    );
  }
}
