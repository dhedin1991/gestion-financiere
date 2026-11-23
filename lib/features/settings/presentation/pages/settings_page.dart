import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/widgets/panel.dart';

/// Page **Paramètres** : réglages regroupés en panneaux par thème.
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
        padding: const EdgeInsets.all(16),
        children: [
          _Group('Sécurité', [
            _Row(Icons.shield_outlined, 'Sécurité et verrouillage',
                'Mot de passe, délai de verrouillage automatique', '/security'),
            _Row(Icons.fact_check_outlined, 'Contrôle d\'intégrité',
                'Vérifier que chaque solde correspond à l\'historique', '/integrity'),
          ]),
          _Group('Apparence', [
            _Row(Icons.palette_outlined, 'Affichage',
                'Zoom, thèmes, polices, fenêtres, recherche', '/display-settings'),
          ]),
          _Group('Données', [
            _Row(Icons.ios_share_outlined, 'Exporter mes données', null, '/export'),
            _Row(Icons.backup_outlined, 'Sauvegarde & restauration', null, '/backup'),
            _Row(Icons.wifi_tethering, 'Synchronisation Wi-Fi',
                'Fusionne les données de deux appareils', '/sync'),
            _Row(Icons.currency_exchange, 'Taux de change',
                'Pour le solde global toutes devises confondues', '/exchange-rates'),
            _Row(Icons.archive_outlined, 'Archives', null, '/archives'),
            _Row(Icons.history, 'Historique des mouvements', null, '/audit-log'),
          ]),
          _Group('Assistance', [
            _Row(Icons.help_outline, 'Mode d\'emploi', null, '/help'),
            _Row(Icons.info_outline, 'Infos application', null, '/app-info'),
          ]),
          const SizedBox(height: 8),
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

class _Group extends StatelessWidget {
  final String title;
  final List<_Row> rows;
  const _Group(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        title: title,
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
        child: Column(children: rows),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String route;
  const _Row(this.icon, this.title, this.subtitle, this.route);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: scheme.primary.withValues(alpha: 0.12),
        child: Icon(icon, size: 18, color: scheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
