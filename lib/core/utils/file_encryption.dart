import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

import 'pbkdf2.dart';

/// Chiffre/déchiffre un fichier entier par mot de passe (AES-256-GCM),
/// utilisé pour les exports (sauvegarde, CSV, PDF) que l'utilisateur veut
/// protéger avant de les partager ou de les stocker ailleurs.
///
/// Format du fichier produit (tout en un seul flux d'octets) :
/// `[magic 4o]['GFE1'][sel 16o][iv 12o][texte chiffré + tag GCM 16o]`
/// Le sel et l'IV sont générés aléatoirement à chaque chiffrement — jamais
/// réutilisés — et stockés en clair au début du fichier : ce n'est pas un
/// secret, seul le mot de passe protège les données. Le tag GCM permet de
/// détecter un mot de passe incorrect ou un fichier corrompu/modifié de
/// façon fiable (échec explicite, jamais un déchiffrement silencieusement
/// faux).
class FileEncryptionException implements Exception {
  final String message;
  const FileEncryptionException(this.message);
  @override
  String toString() => message;
}

class FileEncryption {
  FileEncryption._();

  static final Uint8List _magic = Uint8List.fromList(utf8.encode('GFE1'));
  static const _saltLength = 16;
  static const _ivLength = 12; // taille recommandée pour AES-GCM

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  static Uint8List encryptBytes(Uint8List data, String password) {
    final salt = _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);
    final keyBytes = Pbkdf2.deriveBytes(password: password, salt: salt);

    final encrypter = enc.Encrypter(enc.AES(enc.Key(keyBytes), mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(data, iv: enc.IV(iv));

    final out = BytesBuilder();
    out.add(_magic);
    out.add(salt);
    out.add(iv);
    out.add(encrypted.bytes);
    return out.toBytes();
  }

  static Uint8List decryptBytes(Uint8List payload, String password) {
    if (payload.length < _magic.length + _saltLength + _ivLength) {
      throw const FileEncryptionException('Fichier trop court pour être un export chiffré valide.');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (payload[i] != _magic[i]) {
        throw const FileEncryptionException(
            'Ce fichier ne semble pas être un export chiffré de cette application.');
      }
    }
    var offset = _magic.length;
    final salt = payload.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    final iv = payload.sublist(offset, offset + _ivLength);
    offset += _ivLength;
    final ciphertext = payload.sublist(offset);

    final keyBytes = Pbkdf2.deriveBytes(password: password, salt: salt);
    final encrypter = enc.Encrypter(enc.AES(enc.Key(keyBytes), mode: enc.AESMode.gcm));

    try {
      final decrypted = encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: enc.IV(iv));
      return Uint8List.fromList(decrypted);
    } catch (_) {
      // Le tag GCM ne correspond pas : mot de passe incorrect, ou fichier
      // corrompu/modifié. Message générique volontaire (ne pas aider à
      // deviner lequel des deux).
      throw const FileEncryptionException(
          'Mot de passe incorrect, ou fichier corrompu.');
    }
  }
}
