import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/app_lock_providers.dart';
import '../widgets/pin_dots.dart';
import '../widgets/pin_keypad.dart';

const _pinLength = 4;

/// Écran affiché au lancement de l'app quand un PIN est configuré.
/// Bloque l'accès au reste de l'app tant que le bon code n'est pas saisi.
class PinUnlockPage extends ConsumerStatefulWidget {
  const PinUnlockPage({super.key});

  @override
  ConsumerState<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends ConsumerState<PinUnlockPage> {
  String _entered = '';
  bool _shake = false;
  bool _checking = false;

  void _onDigit(String digit) {
    if (_checking || _entered.length >= _pinLength) return;
    setState(() => _entered += digit);
    if (_entered.length == _pinLength) {
      _submit();
    }
  }

  void _onBackspace() {
    if (_checking || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final ok = await ref.read(appLockControllerProvider.notifier).verify(_entered);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _shake = true;
        _checking = false;
      });
    }
  }

  void _onShakeComplete() {
    setState(() {
      _shake = false;
      _entered = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(Icons.account_balance, size: 40, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'Ma Gestion Financière',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 40),
            Text(
              'Entrez votre code',
              style: GoogleFonts.inter(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            PinDots(
              length: _pinLength,
              filledCount: _entered.length,
              shake: _shake,
              onShakeComplete: _onShakeComplete,
            ),
            const Spacer(flex: 3),
            PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
