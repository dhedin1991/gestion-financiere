import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Déverrouillage par empreinte digitale (Android) ou Windows Hello
/// (empreinte, visage ou code Hello) sur PC.
///
/// L'empreinte n'est qu'un **raccourci** : le mot de passe reste le secret
/// de référence (il est toujours demandé en cas d'échec, de changement
/// d'empreintes ou de refus). Aucune empreinte n'est lue ni stockée par
/// l'application : c'est le système Android qui répond « oui / non ».
class BiometricService {
  static const _enabledKey = 'app_lock_biometric_enabled';

  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  /// Vrai si l'appareil sait lire une empreinte et en a au moins une enregistrée.
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid && !Platform.isWindows) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      // Windows Hello ne sait pas lister les biométries : le test d'appareil suffit.
      if (Platform.isWindows) return true;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    try {
      return await _storage.read(key: _enabledKey) == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value) {
      await _storage.write(key: _enabledKey, value: '1');
    } else {
      await _storage.delete(key: _enabledKey);
    }
  }

  /// Affiche l'invite système. Retourne true seulement si l'empreinte est reconnue.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          // Windows Hello n'accepte pas « biométrie seule » (il propose aussi son code).
          biometricOnly: !Platform.isWindows,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
