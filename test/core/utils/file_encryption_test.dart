import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/utils/file_encryption.dart';

void main() {
  group('FileEncryption', () {
    test('round-trip : les octets déchiffrés sont identiques aux octets d\'origine', () {
      final data = Uint8List.fromList(utf8.encode('Contenu du relevé — montants : 12 345 XOF'));
      final encrypted = FileEncryption.encryptBytes(data, 'motDePasse123');
      final decrypted = FileEncryption.decryptBytes(encrypted, 'motDePasse123');
      expect(decrypted, data);
    });

    test('fonctionne avec des octets binaires quelconques (simulant un PDF/DB)', () {
      final data = Uint8List.fromList(List.generate(5000, (i) => i % 256));
      final encrypted = FileEncryption.encryptBytes(data, 'p@ss');
      final decrypted = FileEncryption.decryptBytes(encrypted, 'p@ss');
      expect(decrypted, data);
    });

    test('un mauvais mot de passe échoue clairement, sans donnée fausse', () {
      final data = Uint8List.fromList(utf8.encode('secret'));
      final encrypted = FileEncryption.encryptBytes(data, 'bonMotDePasse');
      expect(
        () => FileEncryption.decryptBytes(encrypted, 'mauvaisMotDePasse'),
        throwsA(isA<FileEncryptionException>()),
      );
    });

    test('un fichier non reconnu (mauvais en-tête) échoue clairement', () {
      final notEncrypted = Uint8List.fromList(utf8.encode('juste du texte normal, assez long pour passer la taille minimale'));
      expect(
        () => FileEncryption.decryptBytes(notEncrypted, 'peu importe'),
        throwsA(isA<FileEncryptionException>()),
      );
    });

    test('deux chiffrements du même contenu ne produisent jamais le même fichier (sel/IV aléatoires)', () {
      final data = Uint8List.fromList(utf8.encode('même contenu'));
      final a = FileEncryption.encryptBytes(data, 'motdepasse');
      final b = FileEncryption.encryptBytes(data, 'motdepasse');
      expect(a, isNot(equals(b)));
      // Mais les deux se déchiffrent bien vers le même contenu d'origine.
      expect(FileEncryption.decryptBytes(a, 'motdepasse'), data);
      expect(FileEncryption.decryptBytes(b, 'motdepasse'), data);
    });
  });
}
