import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_providers.dart';

/// Page **Paramètres**, unique point d'entrée pour tous les réglages de
/// l'application. Remplace les entrées précédemment éparpillées dans le
/// menu latéral (Sécurité, Apparence, Style, Mode d'emploi, Infos
/// application) par un écran organisé en sections claires — pattern
/// standard des applications professionnelles (une seule page
/// "Paramètres", pas cinq entrées de menu différentes).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Paramètres'),
        actions: const [AppMenuButton()],
      ),
      body: ListView(
        children: [
          _SectionHeader('Sécurité'),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Sécurité et verrouillage'),
            subtitle: const Text('Mot de passe, délai de verrouillage automatique'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/security'),
          ),
          const Divider(height: 24),

          _SectionHeader('Apparence'),
          ListTile(
            leading: Icon(_themeIcon(themeMode)),
            title: const Text('Thème'),
            subtitle: Text(_themeLabel(themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),
          ListTile(
            leading: Icon(Icons.palette_outlined, color: themePreset.swatch),
            title: const Text('Style visuel'),
            subtitle: Text(themePreset.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPresetDialog(context, ref, themePreset),
          ),
          const Divider(height: 24),

          _SectionHeader('Données'),
          ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: const Text('Exporter mes données'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/export'),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Sauvegarde & restauration'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/backup'),
          ),
          ListTile(
            leading: const Icon(Icons.wifi_tethering),
            title: const Text('Synchronisation Wi-Fi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/sync'),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Taux de change'),
            subtitle: const Text('Pour le solde global toutes devises confondues'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/exchange-rates'),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Archives'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/archives'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Journal des actions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/audit-log'),
          ),
          const Divider(height: 24),

          _SectionHeader('Assistance'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Mode d\'emploi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/help'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Infos application'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/app-info'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              kAppName,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
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
        title: const Text('Thème'),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
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
}
