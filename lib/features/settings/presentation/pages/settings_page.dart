import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';

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
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Affichage'),
            subtitle: const Text('Zoom, thèmes, polices, fenêtres, recherche'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/display-settings'),
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
