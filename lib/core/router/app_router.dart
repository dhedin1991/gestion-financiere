import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/debts/presentation/pages/debts_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';
import '../../features/savings/presentation/pages/savings_page.dart';
import '../../features/patrimoine/presentation/pages/patrimoine_page.dart';
import '../../features/credits/presentation/pages/credits_page.dart';
import '../../features/bilans/presentation/pages/bilans_page.dart';
import '../../features/archives/presentation/pages/archives_page.dart';
import '../../features/sync/presentation/pages/sync_page.dart';
import '../navigation/app_drawer.dart';
import '../navigation/scaffold_key_provider.dart';
import 'app_info_page.dart';

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
          GoRoute(
            path: '/savings',
            builder: (context, state) => const SavingsPage(),
          ),
          GoRoute(
            path: '/patrimoine',
            builder: (context, state) => const PatrimoinePage(),
          ),
          GoRoute(
            path: '/credits',
            builder: (context, state) => const CreditsPage(),
          ),
          GoRoute(
            path: '/bilans',
            builder: (context, state) => const BilansPage(),
          ),
          GoRoute(
            path: '/app-info',
            builder: (context, state) => const AppInfoPage(),
          ),
          GoRoute(
            path: '/sync',
            builder: (context, state) => const SyncPage(),
          ),
          GoRoute(
            path: '/archives',
            builder: (context, state) => const ArchivesPage(),
          ),
          // Les futurs modules s'ajouteront ici, un par un.
        ],
      ),
    ],
  );
});

/// Structure commune (menu latéral) partagée par tous les écrans principaux.
class _MainScaffold extends ConsumerWidget {
  final Widget child;
  const _MainScaffold({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldKey = ref.watch(scaffoldKeyProvider);
    final location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      key: scaffoldKey,
      drawer: AppDrawer(currentLocation: location),
      body: child,
    );
  }
}
