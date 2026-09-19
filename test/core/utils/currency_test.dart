import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/utils/currency.dart';

void main() {
  group('pickMainCurrency', () {
    test('aucune donnée : XOF par défaut', () {
      expect(pickMainCurrency(const []), 'XOF');
    });

    test('la devise la plus utilisée gagne', () {
      expect(pickMainCurrency(const ['EUR', 'EUR', 'XOF']), 'EUR');
    });

    test('égalité : XOF prioritaire', () {
      expect(pickMainCurrency(const ['EUR', 'XOF']), 'XOF');
    });

    test('égalité sans XOF : ordre alphabétique', () {
      expect(pickMainCurrency(const ['USD', 'EUR']), 'EUR');
    });
  });
}
