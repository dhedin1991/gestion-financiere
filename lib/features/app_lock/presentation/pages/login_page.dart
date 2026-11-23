import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_logo.dart';
import '../providers/app_lock_providers.dart';
import 'forgot_password_page.dart';

const _kDisplayUsernameKey = 'display_username';

/// Écran de connexion affiché à chaque ouverture de l'app une fois un
/// mot de passe configuré.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _checking = false;
  String? _error;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    // Invite d'empreinte automatique à l'ouverture (si activée).
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_kDisplayUsernameKey);
      if (saved != null && mounted) _usernameController.text = saved;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool _biometricAvailable = false;

  Future<void> _tryBiometric() async {
    final enabled = await ref.read(biometricLoginEnabledProvider.future);
    if (!mounted) return;
    setState(() => _biometricAvailable = enabled);
    if (!enabled) return;
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate('Déverrouille ton application financière');
    if (ok && mounted) ref.read(appLockControllerProvider.notifier).unlock();
  }

  Future<void> _login() async {
    if (_passwordController.text.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });

    final result = await ref.read(appLockControllerProvider.notifier).verify(_passwordController.text);

    if (!result.success) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = result.lockedOut
              ? 'Trop de tentatives. Réessaie dans ${_formatDuration(result.lockoutRemainingSeconds)}.'
              : 'Mot de passe incorrect.';
        });
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (_usernameController.text.trim().isNotEmpty) {
      await prefs.setString(_kDisplayUsernameKey, _usernameController.text.trim());
    }
  }

  void _quit() {
    SystemNavigator.pop();
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds s';
    final minutes = (seconds / 60).ceil();
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary.withValues(alpha: 0.08), scheme.surface],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeController,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(size: 76),
                      const SizedBox(height: 16),
                      Text(
                        kAppName,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bienvenue — connecte-toi pour continuer',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Nom d\'utilisateur',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                          ),
                          child: const Text('Mot de passe oublié ?'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _checking ? null : _login,
                          child: _checking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Connexion'),
                        ),
                      ),
                      if (_biometricAvailable) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _checking ? null : _tryBiometric,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Utiliser l\'empreinte digitale'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _quit,
                          child: const Text('Quitter'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
