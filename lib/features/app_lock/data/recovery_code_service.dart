import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gère un code de récupération local, affiché une seule fois à la
/// création du mot de passe (l'utilisateur doit le noter). Comme il n'y a
/// pas de serveur ni d'e-mail, c'est le seul moyen de réinitialiser le
/// mot de passe en cas d'oubli — exactement comme une clé de
/// récupération d'un outil de chiffrement.
class RecoveryCodeService {
  static const _hashKey = 'app_lock_recovery_hash';
  static const _saltKey = 'app_lock_recovery_salt';

  final _storage = const FlutterSecureStorage();

  /// Génère un nouveau code de récupération (12 caractères, lisible :
  /// lettres majuscules + chiffres, sans caractères ambigus comme 0/O/1/I),
  /// le stocke hashé, et retourne le code en clair pour l'afficher une
  /// seule fois à l'utilisateur.
  Future<String> generateAndStore() async {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final code = List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
    final formatted = '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8, 12)}';

    final salt = _generateSalt();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(code, salt));

    return formatted;
  }

  Future<bool> verify(String code) async {
    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _hashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(_normalize(code), salt) == storedHash;
  }

  String _normalize(String code) => code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  Future<void> clear() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String value, String salt) {
    return sha256.convert(utf8.encode('$salt:$value')).toString();
  }
}
