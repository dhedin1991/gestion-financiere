import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_logo.dart';
import '../providers/app_lock_providers.dart';

/// Vrai si [password] contient au moins une lettre, un chiffre et un
/// caractère spécial, avec une longueur minimale de 8.
bool isPasswordStrongEnough(String password) {
  if (password.length < 8) return false;
  final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  final hasSpecial = RegExp(r'[^a-zA-Z0-9]').hasMatch(password);
  return hasLetter && hasDigit && hasSpecial;
}

/// [onCancel] : si fourni, un bouton retour apparaît (cas "modifier le
/// mot de passe" depuis les réglages). En création initiale, pas
/// d'échappatoire — la connexion est obligatoire.
class PasswordSetupPage extends ConsumerStatefulWidget {
  final VoidCallback? onCancel;

  const PasswordSetupPage({super.key, this.onCancel});

  @override
  ConsumerState<PasswordSetupPage> createState() => _PasswordSetupPageState();
}

class _PasswordSetupPageState extends ConsumerState<PasswordSetupPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (!isPasswordStrongEnough(password)) {
      setState(() => _error =
          'Le mot de passe doit contenir au moins 8 caractères, avec au moins une lettre, un chiffre et un caractère spécial.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Les deux mots de passe ne correspondent pas.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    await ref.read(appLockControllerProvider.notifier).setPassword(password);
    final recoveryCode = await ref.read(recoveryCodeServiceProvider).generateAndStore();

    if (!mounted) return;

    if (widget.onCancel != null) {
      // Modification depuis les réglages : pas besoin de ré-afficher le
      // code de récupération, juste fermer l'écran.
      Navigator.of(context).pop();
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => _RecoveryCodeRevealPage(code: recoveryCode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.onCancel != null)
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(size: 64),
                        const SizedBox(height: 16),
                        Text(
                          widget.onCancel != null ? 'Modifier le mot de passe' : 'Créer ton mot de passe',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.onCancel != null
                              ? 'Choisis un nouveau mot de passe pour $kAppNameShort'
                              : 'Ce mot de passe protégera l\'accès à $kAppNameShort',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscure1,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            helperText: 'Lettres, chiffres et caractère spécial, 8+ caractères',
                            helperMaxLines: 2,
                            suffixIcon: IconButton(
                              icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure1 = !_obscure1),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _confirmController,
                          obscureText: _obscure2,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Confirmer le mot de passe',
                            suffixIcon: IconButton(
                              icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure2 = !_obscure2),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            errorText: _error,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Valider'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Affiche le code de récupération une seule fois, avec confirmation
/// explicite avant de continuer — inspiré des clés de récupération des
/// outils de chiffrement (1Password, BitLocker...).
class _RecoveryCodeRevealPage extends StatefulWidget {
  final String code;
  const _RecoveryCodeRevealPage({required this.code});

  @override
  State<_RecoveryCodeRevealPage> createState() => _RecoveryCodeRevealPageState();
}

class _RecoveryCodeRevealPageState extends State<_RecoveryCodeRevealPage> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.vpn_key_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Ton code de récupération',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Note-le et garde-le en lieu sûr. Sans serveur ni e-mail, c\'est le '
                    'seul moyen de récupérer l\'accès si tu oublies ton mot de passe. '
                    'Il ne sera plus jamais affiché.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SelectableText(
                    widget.code,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 24),
                  CheckboxListTile(
                    value: _confirmed,
                    onChanged: (v) => setState(() => _confirmed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('J\'ai noté mon code de récupération'),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _confirmed
                          ? () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          : null,
                      child: const Text('Continuer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
