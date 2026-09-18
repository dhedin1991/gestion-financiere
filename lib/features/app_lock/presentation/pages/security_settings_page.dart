import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../providers/auto_lock_delay_provider.dart';
import 'password_setup_page.dart';

/// Réglages de sécurité : la connexion par mot de passe est désormais
/// obligatoire (ce n'est plus une option qu'on peut désactiver), donc
/// cet écran ne propose que la modification du mot de passe, le délai de
/// verrouillage automatique, et un rappel du fonctionnement de la
/// récupération.
class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLockDelay = ref.watch(autoLockDelayProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Sécurité'),
        actions: const [AppMenuButton()],
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Connexion par mot de passe'),
            subtitle: Text('Toujours active — c\'est ce qui protège l\'accès à tes données.'),
          ),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('Modifier le mot de passe'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PasswordSetupPage(
                    onCancel: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Verrouillage automatique'),
            subtitle: Text(
              'Reverrouille l\'app ${autoLockDelay.duration == Duration.zero ? "dès la mise en arrière-plan" : "après ${autoLockDelay.label.toLowerCase()} en arrière-plan"}.',
            ),
            trailing: DropdownButton<AutoLockDelay>(
              value: autoLockDelay,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(autoLockDelayProvider.notifier).setDelay(value);
                }
              },
              items: AutoLockDelay.values
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
                  .toList(),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'En cas d\'oubli du mot de passe, seul le code de récupération '
              '(affiché une seule fois à la création du mot de passe) permet de '
              'récupérer l\'accès — il n\'y a pas de serveur ni d\'e-mail pour '
              'réinitialiser autrement.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
