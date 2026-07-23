import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/theme_providers.dart';

/// Menu latéral principal de l'application, listant tous les modules.
/// Remplace l'ancienne barre de navigation du bas, devenue trop chargée
/// avec 9 modules.
class AppDrawer extends ConsumerWidget {
  final String currentLocation;

  const AppDrawer({super.key, required this.currentLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final items = <_DrawerItem>[
      _DrawerItem('Accueil', Icons.dashboard_outlined, Icons.dashboard, '/'),
      _DrawerItem('Comptes', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, '/accounts'),
      _DrawerItem('Transactions', Icons.swap_vert, Icons.swap_vert_circle, '/transactions'),
      _DrawerItem('Dettes & Créances', Icons.handshake_outlined, Icons.handshake, '/debts'),
      _DrawerItem('Budgets', Icons.pie_chart_outline, Icons.pie_chart, '/budgets'),
      _DrawerItem('Épargne', Icons.savings_outlined, Icons.savings, '/savings'),
      _DrawerItem('Patrimoine', Icons.home_work_outlined, Icons.home_work, '/patrimoine'),
      _DrawerItem('Crédits', Icons.request_quote_outlined, Icons.request_quote, '/credits'),
      _DrawerItem('Bilans', Icons.bar_chart_outlined, Icons.bar_chart, '/bilans'),
    ];

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
                      'Gestion Financière',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: items.map((item) {
                  final isSelected = currentLocation == item.route ||
                      (item.route != '/' && currentLocation.startsWith(item.route));
                  return ListTile(
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
                      Navigator.of(context).pop(); // ferme le menu
                      context.go(item.route);
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(_themeIcon(themeMode)),
              title: const Text('Apparence'),
              subtitle: Text(_themeLabel(themeMode)),
              onTap: () => _showThemeDialog(context, ref, themeMode),
            ),
            ListTile(
              leading: Icon(Icons.palette_outlined, color: themePreset.swatch),
              title: const Text('Style'),
              subtitle: Text(themePreset.label),
              onTap: () => _showPresetDialog(context, ref, themePreset),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Sécurité'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/security');
              },
            ),
            ListTile(
              leading: const Icon(Icons.wifi_tethering),
              title: const Text('Synchronisation Wi-Fi'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/sync');
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archives'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/archives');
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Exporter mes données'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/export');
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Sauvegarde & restauration'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/backup');
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Mode d\'emploi'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/help');
              },
            ),
            ListTile(
              leading: const Icon(Icons.autorenew),
              title: const Text('Transactions récurrentes'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/recurring');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Infos application'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/app-info');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
      case ThemeMode.system:
        return 'Automatique (selon l\'appareil)';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode current) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apparence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              value: mode,
              groupValue: current,
              title: Text(_themeLabel(mode)),
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(value);
                }
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPresetDialog(BuildContext context, WidgetRef ref, AppThemePreset current) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Style de l\'application'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppThemePreset.values.map((preset) {
              return RadioListTile<AppThemePreset>(
                value: preset,
                groupValue: current,
                secondary: CircleAvatar(backgroundColor: preset.swatch, radius: 14),
                title: Text(preset.label),
                subtitle: Text(preset.description, style: const TextStyle(fontSize: 12)),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themePresetProvider.notifier).setPreset(value);
                  }
                  Navigator.of(dialogContext).pop();
                },
              );
            }).toList(),
          ),
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
