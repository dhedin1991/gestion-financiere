import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/pbkdf2.dart';
import 'verification_result.dart';

/// Le code de récupération est le seul moyen de reprendre l'accès en cas
/// de mot de passe oublié (pas de serveur, pas d'e-mail) : c'est donc une
/// cible au moins aussi sensible que le mot de passe lui-même, et il
/// applique la même politique de sécurité (PBKDF2 + verrouillage
/// progressif après échecs).
const List<Duration> _lockoutSteps = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
];

class RecoveryCodeService {
  static const _hashKey = 'app_lock_recovery_hash';
  static const _saltKey = 'app_lock_recovery_salt';
  static const _algoKey = 'app_lock_recovery_algo'; // absent => legacy sha256
  static const _iterationsKey = 'app_lock_recovery_iterations';
  static const _failedAttemptsKey = 'app_lock_recovery_failed_attempts';
  static const _lockedUntilKey = 'app_lock_recovery_locked_until';

  static const int _freeAttempts = 4;

  final _storage = const FlutterSecureStorage();

  /// Génère un nouveau code de récupération (12 caractères, lisible :
  /// lettres majuscules + chiffres, sans caractères ambigus comme 0/O/1/I),
  /// le stocke haché (PBKDF2), et retourne le code en clair pour
  /// l'afficher une seule fois à l'utilisateur.
  Future<String> generateAndStore() async {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final code = List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
    final formatted = '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8, 12)}';

    final salt = _generateSaltBytes();
    final hash = await _deriveInBackground(_normalize(code), salt, Pbkdf2.defaultIterations);
    await _storage.write(key: _saltKey, value: base64Url.encode(salt));
    await _storage.write(key: _hashKey, value: hash);
    await _storage.write(key: _algoKey, value: 'pbkdf2');
    await _storage.write(key: _iterationsKey, value: '${Pbkdf2.defaultIterations}');
    await _resetLockoutState();

    return formatted;
  }

  Future<VerificationResult> verify(String code) async {
    final lockRemaining = await _currentLockoutRemaining();
    if (lockRemaining > 0) {
      return VerificationResult.lockout(lockRemaining);
    }

    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _hashKey);
    if (salt == null || storedHash == null) return VerificationResult.failed;

    final normalized = _normalize(code);
    final algo = await _storage.read(key: _algoKey);
    bool matches;
    if (algo == 'pbkdf2') {
      final iterations = int.tryParse(await _storage.read(key: _iterationsKey) ?? '') ??
          Pbkdf2.defaultIterations;
      final saltBytes = base64Url.decode(salt);
      final computed = await _deriveInBackground(normalized, saltBytes, iterations);
      matches = computed == storedHash;
    } else {
      matches = _legacySha256(normalized, salt) == storedHash;
      if (matches) {
        await _migrateLegacyHashIfNeeded(normalized);
      }
    }

    if (matches) {
      await _resetLockoutState();
    } else {
      await _registerFailedAttempt();
    }
    return matches ? VerificationResult.ok : VerificationResult.failed;
  }

  String _normalize(String code) => code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  Future<void> clear() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _algoKey);
    await _storage.delete(key: _iterationsKey);
    await _resetLockoutState();
  }

  Future<void> _migrateLegacyHashIfNeeded(String normalizedCode) async {
    final salt = _generateSaltBytes();
    final hash = await _deriveInBackground(normalizedCode, salt, Pbkdf2.defaultIterations);
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

  String _legacySha256(String value, String salt) {
    return sha256.convert(utf8.encode('$salt:$value')).toString();
  }

  Future<String> _deriveInBackground(String value, List<int> salt, int iterations) {
    return compute(_pbkdf2Isolate, _Pbkdf2Params(value, salt, iterations));
  }
}

class _Pbkdf2Params {
  final String password;
  final List<int> salt;
  final int iterations;
  const _Pbkdf2Params(this.password, this.salt, this.iterations);
}

String _pbkdf2Isolate(_Pbkdf2Params params) {
  return Pbkdf2.deriveHex(
    password: params.password,
    salt: params.salt,
    iterations: params.iterations,
  );
}
