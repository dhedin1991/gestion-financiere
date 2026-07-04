import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/debts/presentation/pages/debts_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';

/// Provider unique du routeur — permet d'injecter facilement une logique
/// de garde (ex: écran de verrouillage biométrique) à cet endroit plus tard,
/// sans toucher le reste de l'app.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsPage(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsPage(),
          ),
          GoRoute(
            path: '/debts',
            builder: (context, state) => const DebtsPage(),
          ),
          GoRoute(
            path: '/budgets',
            builder: (context, state) => const BudgetsPage(),
          ),
          // Les futurs modules (Revenus, Dépenses, Budgets, Crédits,
          // Dettes, Patrimoine, Épargne, Investissements, Objectifs,
          // Échéances, Statistiques, Rapports, Sauvegardes, Paramètres)
          // s'ajouteront ici, un par un, sans rien casser de l'existant.
        ],
      ),
    ],
  );
});

/// Structure commune (barre de navigation basse) partagée par tous les
/// écrans principaux. Prévu pour accueillir les icônes des futurs modules.
class _MainScaffold extends StatelessWidget {
  final Widget child;
  const _MainScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    int currentIndex = 0;
    if (location.startsWith('/accounts')) currentIndex = 1;
    if (location.startsWith('/transactions')) currentIndex = 2;
    if (location.startsWith('/debts')) currentIndex = 3;
    if (location.startsWith('/budgets')) currentIndex = 4;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/accounts');
              break;
            case 2:
              context.go('/transactions');
              break;
            case 3:
              context.go('/debts');
              break;
            case 4:
              context.go('/budgets');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Comptes'),
          NavigationDestination(icon: Icon(Icons.swap_vert), selectedIcon: Icon(Icons.swap_vert_circle), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Dettes'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Budgets'),
        ],
      ),
    );
  }
}
