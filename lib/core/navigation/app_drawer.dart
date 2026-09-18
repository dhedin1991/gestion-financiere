import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';

/// Menu latéral principal de l'application, listant tous les modules.
/// Remplace l'ancienne barre de navigation du bas, devenue trop chargée
/// avec 9 modules.
class AppDrawer extends StatelessWidget {
  final String currentLocation;

  const AppDrawer({super.key, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final items = <_DrawerItem>[
      _DrawerItem('Accueil', Icons.dashboard_outlined, Icons.dashboard, '/'),
    ];
    final comptabilite = <_DrawerItem>[
      _DrawerItem('Comptes', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, '/accounts'),
      _DrawerItem('Transactions', Icons.swap_vert, Icons.swap_vert_circle, '/transactions'),
      _DrawerItem('Transactions récurrentes', Icons.autorenew, Icons.autorenew, '/recurring'),
      _DrawerItem('Budgets', Icons.pie_chart_outline, Icons.pie_chart, '/budgets'),
    ];
    final patrimoineItems = <_DrawerItem>[
      _DrawerItem('Épargne', Icons.savings_outlined, Icons.savings, '/savings'),
      _DrawerItem('Crédits', Icons.request_quote_outlined, Icons.request_quote, '/credits'),
      _DrawerItem('Dettes & Créances', Icons.handshake_outlined, Icons.handshake, '/debts'),
      _DrawerItem('Patrimoine', Icons.home_work_outlined, Icons.home_work, '/patrimoine'),
      _DrawerItem('Bilans', Icons.bar_chart_outlined, Icons.bar_chart, '/bilans'),
    ];
    final outils = <_DrawerItem>[
      _DrawerItem('Exporter mes données', Icons.ios_share_outlined, Icons.ios_share, '/export'),
      _DrawerItem('Sauvegarde & restauration', Icons.backup_outlined, Icons.backup, '/backup'),
      _DrawerItem('Synchronisation Wi-Fi', Icons.wifi_tethering, Icons.wifi_tethering, '/sync'),
      _DrawerItem('Archives', Icons.archive_outlined, Icons.archive, '/archives'),
      _DrawerItem('Journal des actions', Icons.history, Icons.history, '/audit-log'),
    ];

    Widget buildItem(_DrawerItem item) {
      final isSelected = currentLocation == item.route ||
          (item.route != '/' && currentLocation.startsWith(item.route));
      return ListTile(
        dense: true,
        leading: Icon(
          isSelected ? item.selectedIcon : item.icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        onTap: () {
          Navigator.of(context).pop();
          if (item.route != currentLocation) context.go(item.route);
        },
      );
    }

    Widget sectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      kAppNameShort,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ...items.map(buildItem),
                  sectionHeader('Comptabilité'),
                  ...comptabilite.map(buildItem),
                  sectionHeader('Patrimoine'),
                  ...patrimoineItems.map(buildItem),
                  sectionHeader('Outils'),
                  ...outils.map(buildItem),
                  sectionHeader('Application'),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Paramètres'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/settings');
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const _DrawerItem(this.label, this.icon, this.selectedIcon, this.route);
}
