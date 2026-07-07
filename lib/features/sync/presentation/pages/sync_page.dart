import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_menu_button.dart';
import '../providers/sync_providers.dart';

class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  final _ipController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const AppMenuButton(),
        title: const Text('Synchronisation Wi-Fi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.amber.withOpacity(0.15),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'La synchronisation remplace TOUTES les données de l\'appareil '
                      'qui reçoit par celles de l\'appareil qui partage. Assure-toi de '
                      'partager depuis l\'appareil qui a les données les plus à jour.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ---------- SECTION 1 : Partager mes données ----------
          Text('1. Partager les données de cet appareil', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Utilise cette option sur l\'appareil qui a les données à jour.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (syncState.status == SyncStatus.serverRunning) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_tethering, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Partage actif', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Sur l\'autre appareil, saisis cette adresse :'),
                    const SizedBox(height: 8),
                    SelectableText(
                      syncState.serverIpAddress ?? 'Adresse introuvable',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: controller.stopServer,
                      icon: const Icon(Icons.stop),
                      label: const Text('Arrêter le partage'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => controller.startServer(),
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Démarrer le partage'),
            ),
          ],

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),

          // ---------- SECTION 2 : Recevoir des données ----------
          Text('2. Recevoir les données d\'un autre appareil', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Utilise cette option sur l\'appareil à mettre à jour. '
            'Toutes ses données actuelles seront remplacées.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'Adresse de l\'autre appareil',
              hintText: 'ex: 192.168.1.25',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (syncState.status == SyncStatus.connecting || syncState.status == SyncStatus.syncing)
                ? null
                : () => _confirmAndSync(context, controller),
            icon: const Icon(Icons.download),
            label: const Text('Recevoir et remplacer mes données'),
          ),

          const SizedBox(height: 24),

          // ---------- Statut ----------
          if (syncState.status == SyncStatus.connecting) ...[
            const _StatusCard(
              icon: Icons.search,
              color: Colors.blue,
              message: 'Recherche de l\'appareil...',
              loading: true,
            ),
          ] else if (syncState.status == SyncStatus.syncing) ...[
            const _StatusCard(
              icon: Icons.sync,
              color: Colors.blue,
              message: 'Synchronisation en cours, ne ferme pas l\'application...',
              loading: true,
            ),
          ] else if (syncState.status == SyncStatus.success) ...[
            _StatusCard(
              icon: Icons.check_circle,
              color: Colors.green,
              message: 'Synchronisation réussie ! Redémarre l\'application pour voir les nouvelles données.',
              loading: false,
              onDismiss: controller.reset,
            ),
          ] else if (syncState.status == SyncStatus.error) ...[
            _StatusCard(
              icon: Icons.error_outline,
              color: Colors.red,
              message: syncState.errorMessage ?? 'Une erreur est survenue.',
              loading: false,
              onDismiss: controller.reset,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAndSync(BuildContext context, SyncController controller) async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer la synchronisation'),
        content: Text(
          'Toutes les données actuelles de CET appareil vont être remplacées '
          'par celles de l\'appareil à l\'adresse $ip. Cette action est irréversible. Continuer ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remplacer mes données', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.syncFromServer(ip);
    }
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final bool loading;
  final VoidCallback? onDismiss;

  const _StatusCard({
    required this.icon,
    required this.color,
    required this.message,
    required this.loading,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (loading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            if (onDismiss != null)
              IconButton(icon: const Icon(Icons.close), onPressed: onDismiss),
          ],
        ),
      ),
    );
  }
}
