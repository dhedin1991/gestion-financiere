import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/pbkdf2.dart';
import 'verification_result.dart';

/// Palier de verrouillage progressif après plusieurs échecs consécutifs :
/// l'index dans cette liste correspond au nombre d'échecs au-delà du
/// seuil de tolérance ([_freeAttempts]), la valeur à la durée du blocage.
const List<Duration> _lockoutSteps = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
];

/// Gère le stockage du code PIN/mot de passe de verrouillage de l'app.
///
/// Le mot de passe n'est jamais stocké en clair : on stocke un sel
/// aléatoire et une empreinte **PBKDF2-HMAC-SHA256** (voir
/// `core/utils/pbkdf2.dart`), beaucoup plus résistante au brute-force
/// hors-ligne qu'un simple SHA-256. `flutter_secure_storage` s'appuie en
/// plus sur le Keystore Android / Keychain iOS : même cette empreinte
/// n'est donc pas lisible en fouillant simplement les fichiers de l'app.
///
/// Une installation existante peut avoir une empreinte au format
/// précédent (SHA-256 simple, sans marqueur d'algorithme) : elle est
/// vérifiée une dernière fois avec l'ancienne méthode puis transparemment
/// migrée vers PBKDF2 en cas de succès (voir [_migrateLegacyHashIfNeeded]).
///
/// Ce service applique aussi un **verrouillage progressif** après
/// plusieurs échecs consécutifs, pour rendre un brute-force en ligne
/// (quelqu'un qui essaie des codes à la main sur l'appareil déverrouillé)
/// impraticable.
class PinStorageService {
  static const _hashKey = 'app_lock_pin_hash';
  static const _saltKey = 'app_lock_pin_salt';
  static const _algoKey = 'app_lock_pin_algo'; // absent => legacy sha256
  static const _iterationsKey = 'app_lock_pin_iterations';
  static const _failedAttemptsKey = 'app_lock_pin_failed_attempts';
  static const _lockedUntilKey = 'app_lock_pin_locked_until';

  static const int _freeAttempts = 4;

  final _storage = const FlutterSecureStorage();

  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _hashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSaltBytes();
    final hash = await _deriveInBackground(pin, salt, Pbkdf2.defaultIterations);
    await _storage.write(key: _saltKey, value: base64Url.encode(salt));
    await _storage.write(key: _hashKey, value: hash);
    await _storage.write(key: _algoKey, value: 'pbkdf2');
    await _storage.write(key: _iterationsKey, value: '${Pbkdf2.defaultIterations}');
    await _resetLockoutState();
  }

  /// Vérifie le mot de passe saisi. Retourne un [VerificationResult] qui
  /// indique soit le succès/échec, soit un verrouillage temporaire en
  /// cours (auquel cas la tentative n'a même pas été évaluée).
  Future<VerificationResult> verifyPin(String pin) async {
    final lockRemaining = await _currentLockoutRemaining();
    if (lockRemaining > 0) {
      return VerificationResult.lockout(lockRemaining);
    }

    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _hashKey);
    if (salt == null || storedHash == null) return VerificationResult.failed;

    final algo = await _storage.read(key: _algoKey);
    bool matches;
    if (algo == 'pbkdf2') {
      final iterations = int.tryParse(await _storage.read(key: _iterationsKey) ?? '') ??
          Pbkdf2.defaultIterations;
      final saltBytes = base64Url.decode(salt);
      final computed = await _deriveInBackground(pin, saltBytes, iterations);
      matches = computed == storedHash;
    } else {
      // Format historique : sel encodé en base64Url "texte", hash SHA-256
      // simple de "sel:pin". Conservé uniquement pour permettre la
      // migration transparente des installations existantes.
      matches = _legacySha256(pin, salt) == storedHash;
      if (matches) {
        await _migrateLegacyHashIfNeeded(pin);
      }
    }

    if (matches) {
      await _resetLockoutState();
    } else {
      await _registerFailedAttempt();
    }
    return matches ? VerificationResult.ok : VerificationResult.failed;
  }

  /// Supprime le mot de passe (désactive le verrouillage). Ne touche pas
  /// aux données financières, uniquement au verrouillage lui-même.
  Future<void> clearPin() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _algoKey);
    await _storage.delete(key: _iterationsKey);
    await _resetLockoutState();
  }

  Future<void> _migrateLegacyHashIfNeeded(String pin) async {
    final salt = _generateSaltBytes();
    final hash = await _deriveInBackground(pin, salt, Pbkdf2.defaultIterations);
    await _storage.write(key: _saltKey, value: base64Url.encode(salt));
    await _storage.write(key: _hashKey, value: hash);
    await _storage.write(key: _algoKey, value: 'pbkdf2');
    await _storage.write(key: _iterationsKey, value: '${Pbkdf2.defaultIterations}');
  }

  Future<int> _currentLockoutRemaining() async {
    final raw = await _storage.read(key: _lockedUntilKey);
    if (raw == null) return 0;
    final lockedUntil = DateTime.tryParse(raw);
    if (lockedUntil == null) return 0;
    final remaining = lockedUntil.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _registerFailedAttempt() async {
    final current = int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '0') ?? 0;
    final updated = current + 1;
    await _storage.write(key: _failedAttemptsKey, value: '$updated');

    final overLimit = updated - _freeAttempts;
    if (overLimit > 0) {
      final stepIndex = (overLimit - 1).clamp(0, _lockoutSteps.length - 1);
      final lockDuration = _lockoutSteps[stepIndex];
      final lockedUntil = DateTime.now().add(lockDuration);
      await _storage.write(key: _lockedUntilKey, value: lockedUntil.toIso8601String());
    }
  }

  Future<void> _resetLockoutState() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockedUntilKey);
  }

  List<int> _generateSaltBytes() {
    final rng = Random.secure();
    return List<int>.generate(16, (_) => rng.nextInt(256));
  }

  String _legacySha256(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  /// Exécute PBKDF2 dans un isolate séparé (`compute`) pour ne jamais
  /// bloquer l'interface le temps du calcul (quelques dizaines à
  /// centaines de ms selon l'appareil).
  Future<String> _deriveInBackground(String pin, List<int> salt, int iterations) {
    return compute(_pbkdf2Isolate, _Pbkdf2Params(pin, salt, iterations));
  }
}

class _Pbkdf2Params {
  final String password;
  final List<int> salt;
  final int iterations;
  const _Pbkdf2Params(this.password, this.salt, this.iterations);
}

/// Doit être une fonction top-level (ou statique) pour être utilisable
/// avec `compute()`.
String _pbkdf2Isolate(_Pbkdf2Params params) {
  return Pbkdf2.deriveHex(
    password: params.password,
    salt: params.salt,
    iterations: params.iterations,
  );
}
