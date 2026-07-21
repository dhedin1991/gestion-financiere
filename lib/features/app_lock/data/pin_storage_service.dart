import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gère le stockage du code PIN de verrouillage de l'application.
///
/// Le PIN n'est jamais stocké en clair : on stocke un sel aléatoire (généré
/// une fois) et le hash SHA-256 de (sel + PIN). `flutter_secure_storage`
/// s'appuie sur le Keystore Android / Keychain iOS, donc même ce hash n'est
/// pas lisible en fouillant simplement dans les fichiers de l'app.
class PinStorageService {
  static const _hashKey = 'app_lock_pin_hash';
  static const _saltKey = 'app_lock_pin_salt';

  final _storage = const FlutterSecureStorage();

  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _hashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _hashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(pin, salt) == storedHash;
  }

  /// Supprime le PIN (désactive le verrouillage). Ne touche pas aux
  /// données financières, uniquement au verrouillage lui-même.
  Future<void> clearPin() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }
}
