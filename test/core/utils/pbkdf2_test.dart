import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/utils/pbkdf2.dart';

void main() {
  group('Pbkdf2', () {
    test('est déterministe : mêmes entrées => même sortie', () {
      final a = Pbkdf2.deriveHex(password: 'motdepasse', salt: [1, 2, 3, 4], iterations: 1000);
      final b = Pbkdf2.deriveHex(password: 'motdepasse', salt: [1, 2, 3, 4], iterations: 1000);
      expect(a, equals(b));
    });

    test('longueur de sortie = 2 * keyLengthBytes (hexadécimal)', () {
      final hex16 = Pbkdf2.deriveHex(
        password: 'x',
        salt: [1],
        iterations: 10,
        keyLengthBytes: 16,
      );
      expect(hex16.length, 32);

      final hex32 = Pbkdf2.deriveHex(
        password: 'x',
        salt: [1],
        iterations: 10,
        keyLengthBytes: 32,
      );
      expect(hex32.length, 64);
    });

    test('un sel différent produit une sortie différente', () {
      final a = Pbkdf2.deriveHex(password: 'motdepasse', salt: [1, 2, 3], iterations: 1000);
      final b = Pbkdf2.deriveHex(password: 'motdepasse', salt: [4, 5, 6], iterations: 1000);
      expect(a, isNot(equals(b)));
    });

    test('un nombre d\'itérations différent produit une sortie différente', () {
      final a = Pbkdf2.deriveHex(password: 'motdepasse', salt: [1, 2, 3], iterations: 100);
      final b = Pbkdf2.deriveHex(password: 'motdepasse', salt: [1, 2, 3], iterations: 200);
      expect(a, isNot(equals(b)));
    });

    test('un mot de passe différent produit une sortie différente', () {
      final a = Pbkdf2.deriveHex(password: 'abc', salt: [1, 2, 3], iterations: 500);
      final b = Pbkdf2.deriveHex(password: 'abd', salt: [1, 2, 3], iterations: 500);
      expect(a, isNot(equals(b)));
    });

    test('gère correctement les caractères accentués (mots de passe FR)', () {
      // Régression : une implémentation naïve qui encoderait le mot de
      // passe en ASCII planterait ou tronquerait silencieusement les
      // caractères comme é/è/à, très probables dans un mot de passe
      // saisi par un utilisateur francophone.
      expect(
        () => Pbkdf2.deriveHex(password: 'motDePasséÀÉ', salt: [1, 2], iterations: 100),
        returnsNormally,
      );
      final a = Pbkdf2.deriveHex(password: 'café', salt: [9], iterations: 100);
      final b = Pbkdf2.deriveHex(password: 'cafe', salt: [9], iterations: 100);
      expect(a, isNot(equals(b)));
    });

    test('une clé plus longue que 32 octets (un seul bloc SHA-256) fonctionne', () {
      final hex = Pbkdf2.deriveHex(
        password: 'x',
        salt: [1],
        iterations: 10,
        keyLengthBytes: 48,
      );
      expect(hex.length, 96);
    });
  });
}
