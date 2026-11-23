import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../providers/app_lock_providers.dart';
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
          const _BiometricTile(),
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

/// Interrupteur « empreinte digitale ». Invisible si l'appareil n'a pas de
/// lecteur ou aucune empreinte enregistrée. L'activation exige de poser le
/// doigt une première fois, pour être sûr que ça fonctionne.
class _BiometricTile extends ConsumerStatefulWidget {
  const _BiometricTile();

  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool _available = false;
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(biometricServiceProvider);
    final available = await service.isAvailable();
    final enabled = await service.isEnabled();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
      _loaded = true;
    });
  }

  Future<void> _toggle(bool value) async {
    final service = ref.read(biometricServiceProvider);
    if (value) {
      final ok = await service.authenticate('Confirme avec ton empreinte pour activer le déverrouillage');
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Empreinte non reconnue : réglage inchangé.')),
          );
        }
        return;
      }
    }
    await service.setEnabled(value);
    ref.invalidate(biometricLoginEnabledProvider);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (!_available) {
      return const ListTile(
        leading: Icon(Icons.fingerprint),
        title: Text('Empreinte digitale'),
        subtitle: Text(
          'Indisponible : aucun lecteur, aucune empreinte enregistrée dans les réglages '
          'du téléphone, ou appareil non Android.',
        ),
      );
    }
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Déverrouiller avec l\'empreinte digitale'),
      subtitle: const Text('Le mot de passe reste demandé si l\'empreinte échoue.'),
      value: _enabled,
      onChanged: _toggle,
    );
  }
}
