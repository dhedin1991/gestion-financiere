import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_lock_providers.dart';
import 'pin_setup_page.dart';

/// Réglages de sécurité : activer/désactiver le verrouillage par code PIN,
/// ou modifier le code existant. Accessible uniquement une fois dans
/// l'app (donc déjà authentifié si un verrouillage était actif).
class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(appLockControllerProvider).phase;
    final lockEnabled = phase == AppLockPhase.unlocked || phase == AppLockPhase.locked;

    return Scaffold(
      appBar: AppBar(title: const Text('Sécurité')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Verrouillage par code PIN'),
            subtitle: const Text('Demande un code à 4 chiffres à chaque ouverture de l\'app'),
            value: lockEnabled,
            onChanged: (value) async {
              if (value) {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PinSetupPage()),
                );
              } else {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Désactiver le verrouillage ?'),
                    content: const Text(
                      'N\'importe qui ayant accès à ton téléphone pourra ouvrir l\'app sans code.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Désactiver'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(appLockControllerProvider.notifier).disableLock();
                }
              }
            },
          ),
          if (lockEnabled)
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Modifier le code'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PinSetupPage(
                      onCancel: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
