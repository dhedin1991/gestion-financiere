import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/utils/money.dart';

void main() {
  group('Money.toCents / fromCents', () {
    test('convertit unités -> centimes -> unités sans perte', () {
      expect(Money.toCents(1500.50), 150050);
      expect(Money.fromCents(150050), 1500.50);
    });

    test('arrondit correctement au centime le plus proche', () {
      expect(Money.toCents(10.006), 1001); // clairement au-dessus de la moitié
      expect(Money.toCents(10.004), 1000); // clairement en-dessous
    });

    test('corrige les imprécisions classiques des flottants', () {
      final sum = 0.1 + 0.2; // 0.30000000000000004 en IEEE-754
      expect(Money.toCents(sum), 30); // et non 29 ou 31
    });

    test('gère zéro et les valeurs négatives', () {
      expect(Money.toCents(0.0), 0);
      expect(Money.toCents(-42.5), -4250);
      expect(Money.fromCents(-4250), -42.5);
    });

    test('toCentsOrNull / fromCentsOrNull gèrent le null', () {
      expect(Money.toCentsOrNull(null), isNull);
      expect(Money.fromCentsOrNull(null), isNull);
      expect(Money.toCentsOrNull(12.34), 1234);
      expect(Money.fromCentsOrNull(1234), 12.34);
    });

    test('un aller-retour ne dérive jamais, même après de nombreuses opérations', () {
      // Simule 1000 additions de 0.1 comme le ferait un historique de
      // transactions : en flottant pur, cela dérive perceptiblement ;
      // en passant par les centimes entiers à chaque écriture, non.
      var totalCents = 0;
      for (var i = 0; i < 1000; i++) {
        totalCents += Money.toCents(0.1);
      }
      expect(Money.fromCents(totalCents), 100.0);
    });
  });

  group('Money.round', () {
    test('arrondit à 2 décimales', () {
      expect(Money.round(10.005), closeTo(10.01, 0.001));
      expect(Money.round(10.004), closeTo(10.00, 0.001));
    });

    test('corrige les imprécisions classiques des flottants', () {
      final sum = 0.1 + 0.2;
      expect(sum == 0.3, isFalse);
      expect(Money.round(sum), 0.3);
    });
  });

  group('Money.equals', () {
    test('considère 0.1 + 0.2 comme égal à 0.3', () {
      expect(Money.equals(0.1 + 0.2, 0.3), isTrue);
    });

    test('détecte une vraie différence', () {
      expect(Money.equals(10.0, 10.5), isFalse);
    });
  });
}
