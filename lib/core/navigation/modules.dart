import 'package:flutter/material.dart';

import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/app_lock/presentation/pages/security_settings_page.dart';
import '../../features/archives/presentation/pages/archives_page.dart';
import '../../features/audit_log/presentation/pages/audit_log_page.dart';
import '../../features/backup/presentation/pages/backup_page.dart';
import '../../features/bilans/presentation/pages/bilans_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';
import '../../features/credits/presentation/pages/credits_page.dart';
import '../../features/dashboard/presentation/pages/home_page.dart';
import '../../features/debts/presentation/pages/debts_page.dart';
import '../../features/export/presentation/pages/export_page.dart';
import '../../features/help/presentation/pages/help_page.dart';
import '../../features/invoicing/presentation/pages/invoicing_page.dart';
import '../../features/patrimoine/presentation/pages/patrimoine_page.dart';
import '../../features/recurring/presentation/pages/recurring_transactions_page.dart';
import '../../features/savings/presentation/pages/savings_page.dart';
import '../../features/settings/presentation/pages/display_settings_page.dart';
import '../../features/settings/presentation/pages/exchange_rates_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/sync/presentation/pages/sync_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../router/app_info_page.dart';

/// Un écran de l'application : source unique pour le menu, les onglets, la
/// recherche et le routeur.
class AppModule {
  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String section;
  final bool inNav; // affiché dans le Navigateur / le menu
  final Color? dot;
  final Widget Function() builder;

  const AppModule({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.section,
    required this.builder,
    this.inNav = true,
    this.dot,
  });
}

final List<AppModule> kModules = [
  AppModule(label: 'Accueil', route: '/', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, section: 'Général', builder: () => const HomePage()),
  AppModule(label: 'Statistiques', route: '/statistics', icon: Icons.insights_outlined, selectedIcon: Icons.insights, section: 'Général', builder: () => const StatisticsPage()),
  AppModule(label: 'Comptes', route: '/accounts', icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet, section: 'Comptabilité', builder: () => const AccountsPage()),
  AppModule(label: 'Revenus & Dépenses', route: '/transactions', icon: Icons.swap_vert, selectedIcon: Icons.swap_vert_circle, section: 'Comptabilité', builder: () => const TransactionsPage()),
  AppModule(label: 'Transactions récurrentes', route: '/recurring', icon: Icons.autorenew, selectedIcon: Icons.autorenew, section: 'Comptabilité', builder: () => const RecurringTransactionsPage()),
  AppModule(label: 'Budgets', route: '/budgets', icon: Icons.pie_chart_outline, selectedIcon: Icons.pie_chart, section: 'Comptabilité', builder: () => const BudgetsPage()),
  AppModule(label: 'Facturation', route: '/invoicing', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, section: 'Comptabilité', builder: () => const InvoicingPage()),
  AppModule(label: 'Épargne', route: '/savings', icon: Icons.savings_outlined, selectedIcon: Icons.savings, section: 'Patrimoine', builder: () => const SavingsPage()),
  AppModule(label: 'Crédits', route: '/credits', icon: Icons.request_quote_outlined, selectedIcon: Icons.request_quote, section: 'Patrimoine', builder: () => const CreditsPage()),
  AppModule(label: 'Dettes & Créances', route: '/debts', icon: Icons.handshake_outlined, selectedIcon: Icons.handshake, section: 'Patrimoine', builder: () => const DebtsPage()),
  AppModule(label: 'Patrimoine', route: '/patrimoine', icon: Icons.home_work_outlined, selectedIcon: Icons.home_work, section: 'Patrimoine', builder: () => const PatrimoinePage()),
  AppModule(label: 'Bilans', route: '/bilans', icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, section: 'Patrimoine', builder: () => const BilansPage()),
  AppModule(label: 'Exporter mes données', route: '/export', icon: Icons.ios_share_outlined, selectedIcon: Icons.ios_share, section: 'Outils', builder: () => const ExportPage()),
  AppModule(label: 'Sauvegarde & restauration', route: '/backup', icon: Icons.backup_outlined, selectedIcon: Icons.backup, section: 'Outils', builder: () => const BackupPage()),
  AppModule(label: 'Synchronisation Wi-Fi', route: '/sync', icon: Icons.wifi_tethering, selectedIcon: Icons.wifi_tethering, section: 'Outils', builder: () => const SyncPage()),
  AppModule(label: 'Archives', route: '/archives', icon: Icons.archive_outlined, selectedIcon: Icons.archive, section: 'Outils', builder: () => const ArchivesPage()),
  AppModule(label: 'Journal des actions', route: '/audit-log', icon: Icons.history, selectedIcon: Icons.history, section: 'Outils', builder: () => const AuditLogPage()),
  AppModule(label: 'Paramètres', route: '/settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings, section: 'Application', builder: () => const SettingsPage()),
  AppModule(label: 'Affichage', route: '/display-settings', icon: Icons.palette_outlined, selectedIcon: Icons.palette, section: 'Application', inNav: false, builder: () => const DisplaySettingsPage()),
  AppModule(label: 'Taux de change', route: '/exchange-rates', icon: Icons.currency_exchange, selectedIcon: Icons.currency_exchange, section: 'Application', inNav: false, builder: () => const ExchangeRatesPage()),
  AppModule(label: 'Sécurité', route: '/security', icon: Icons.shield_outlined, selectedIcon: Icons.shield, section: 'Application', inNav: false, builder: () => const SecuritySettingsPage()),
  AppModule(label: 'Mode d’emploi', route: '/help', icon: Icons.help_outline, selectedIcon: Icons.help, section: 'Application', inNav: false, builder: () => const HelpPage()),
  AppModule(label: 'Infos application', route: '/app-info', icon: Icons.info_outline, selectedIcon: Icons.info, section: 'Application', inNav: false, builder: () => const AppInfoPage()),
];

AppModule? moduleForRoute(String route) {
  for (final m in kModules) {
    if (m.route == route) return m;
  }
  return null;
}

const List<String> kSections = ['Général', 'Comptabilité', 'Patrimoine', 'Outils', 'Application'];
