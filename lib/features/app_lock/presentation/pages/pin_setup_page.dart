import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/app_lock_providers.dart';
import '../widgets/pin_dots.dart';
import '../widgets/pin_keypad.dart';

const _pinLength = 4;

/// Écran de création d'un nouveau PIN : demande le code deux fois pour
/// éviter une faute de frappe qui bloquerait l'utilisateur au prochain
/// démarrage.
///
/// [onCancel] : si fourni, un bouton retour apparaît (cas "modifier le PIN"
/// depuis les réglages). En création initiale, pas d'échappatoire.
class PinSetupPage extends ConsumerStatefulWidget {
  final VoidCallback? onCancel;

  const PinSetupPage({super.key, this.onCancel});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  String _first = '';
  String _entered = '';
  bool _confirming = false;
  bool _shake = false;

  void _onDigit(String digit) {
    if (_entered.length >= _pinLength) return;
    setState(() => _entered += digit);
    if (_entered.length == _pinLength) {
      _handleComplete();
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _handleComplete() async {
    if (!_confirming) {
      // Première saisie terminée : on passe à la confirmation.
      setState(() {
        _first = _entered;
        _entered = '';
        _confirming = true;
      });
      return;
    }

    if (_entered == _first) {
      await ref.read(appLockControllerProvider.notifier).enableLock(_entered);
      if (widget.onCancel != null && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() => _shake = true);
    }
  }

  void _onShakeComplete() {
    // Codes différents : on recommence tout depuis le début.
    setState(() {
      _shake = false;
      _entered = '';
      _first = '';
      _confirming = false;
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
            if (widget.onCancel != null)
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                ),
              ),
            Spacer(flex: widget.onCancel != null ? 1 : 2),
            Icon(Icons.lock_outline, size: 40, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              _confirming ? 'Confirmez votre code' : 'Choisissez un code',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _confirming
                  ? 'Ressaisissez le même code à 4 chiffres'
                  : 'Ce code protégera l\'accès à vos données financières',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
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
