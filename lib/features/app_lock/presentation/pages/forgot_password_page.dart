import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/app_lock_providers.dart';
import 'password_setup_page.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _codeController = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkCode() async {
    if (_codeController.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final valid = await ref.read(recoveryCodeServiceProvider).verify(_codeController.text);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!valid) {
      setState(() => _error = 'Code de récupération incorrect.');
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PasswordSetupPage(
          onCancel: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
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
                    'Entre ton code de récupération',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Le code à 12 caractères qui t\'a été montré lors de la création '
                    'de ton mot de passe.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'XXXX-XXXX-XXXX',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _checkCode,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Vérifier'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sans ce code, il n\'existe aucun autre moyen de récupérer l\'accès : '
                    'toutes les données restent en local, sans serveur externe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
