import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Implémentation de PBKDF2-HMAC-SHA256 (RFC 8018), volontairement sans
/// dépendance supplémentaire : construite uniquement sur `package:crypto`
/// (déjà présent dans `pubspec.yaml`), pour ne pas ajouter de plugin natif
/// non testé à ce stade.
///
/// Remplace le simple `sha256(sel + pin)` utilisé auparavant pour le PIN
/// et le code de récupération : un hash simple se calcule en microsecondes,
/// ce qui rendrait un brute-force hors-ligne (si le hash venait à fuiter)
/// beaucoup trop rapide. PBKDF2 avec un grand nombre d'itérations ralentit
/// délibérément chaque tentative.
///
/// ⚠️ [defaultIterations] est volontairement plus bas que la recommandation
/// OWASP pour un *serveur web* (600 000+) : ce hash tourne sur l'appareil
/// de l'utilisateur, potentiellement un téléphone d'entrée de gamme, et
/// doit rester supportable pour ne pas bloquer l'app plusieurs secondes à
/// chaque déverrouillage. Il s'agit de toute façon d'une défense en
/// profondeur : le hash est stocké via `flutter_secure_storage`
/// (Keystore Android / Keychain iOS), pas dans un fichier accessible
/// directement. Cet appel doit être exécuté dans un isolate séparé (voir
/// `compute()` dans `PinStorageService`) pour ne jamais bloquer l'UI.
class Pbkdf2 {
  Pbkdf2._();

  static const int defaultIterations = 120000;
  static const int defaultKeyLengthBytes = 32; // 256 bits

  /// Dérive une clé à partir d'un mot de passe/PIN et d'un sel, et
  /// retourne le résultat encodé en hexadécimal.
  static String deriveHex({
    required String password,
    required List<int> salt,
    int iterations = defaultIterations,
    int keyLengthBytes = defaultKeyLengthBytes,
  }) {
    final bytes = _derive(
      password: utf8.encode(password),
      salt: salt,
      iterations: iterations,
      keyLengthBytes: keyLengthBytes,
    );
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Comme [deriveHex], mais retourne directement les octets bruts —
  /// utilisé pour dériver une clé de chiffrement AES (pas seulement un
  /// hash à comparer).
  static Uint8List deriveBytes({
    required String password,
    required List<int> salt,
    int iterations = defaultIterations,
    int keyLengthBytes = defaultKeyLengthBytes,
  }) {
    return _derive(
      password: utf8.encode(password),
      salt: salt,
      iterations: iterations,
      keyLengthBytes: keyLengthBytes,
    );
  }

  static Uint8List _derive({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLengthBytes,
  }) {
    if (iterations < 1) {
      throw ArgumentError.value(iterations, 'iterations', 'doit être >= 1');
    }
    final hmac = Hmac(sha256, password);
    const hashLenBytes = 32; // sortie de sha256 = 32 octets
    final blockCount = (keyLengthBytes / hashLenBytes).ceil();
    final result = BytesBuilder();

    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final indexBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, blockIndex, Endian.big);

      // U_1 = PRF(P, S || INT_32_BE(i))
      var u = hmac.convert([...salt, ...indexBytes]).bytes;
      final t = List<int>.from(u);

      // U_2..U_c, XOR-és au fur et à mesure dans T_i.
      for (var j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      result.add(t);
    }

    return result.toBytes().sublist(0, keyLengthBytes);
  }
}
