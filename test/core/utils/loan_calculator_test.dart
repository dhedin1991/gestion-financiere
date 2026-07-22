import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/utils/loan_calculator.dart';

void main() {
  group('calculateMonthlyPayment', () {
    test('calcule correctement une mensualité avec intérêts', () {
      // Référence : emprunt de 1 000 000 sur 12 mois à 12%/an → mensualité ≈ 88 849
      final payment = calculateMonthlyPayment(
        principal: 1000000,
        annualRatePercent: 12,
        durationMonths: 12,
      );
      expect(payment, isNotNull);
      expect(payment!, closeTo(88849, 1));
    });

    test('taux à 0% : mensualité = capital / durée, sans intérêts', () {
      final payment = calculateMonthlyPayment(
        principal: 120000,
        annualRatePercent: 0,
        durationMonths: 12,
      );
      expect(payment, equals(10000));
    });

    test('retourne null si le capital est nul ou négatif', () {
      expect(
        calculateMonthlyPayment(principal: 0, annualRatePercent: 5, durationMonths: 12),
        isNull,
      );
      expect(
        calculateMonthlyPayment(principal: -100, annualRatePercent: 5, durationMonths: 12),
        isNull,
      );
    });

    test('retourne null si la durée est nulle ou négative', () {
      expect(
        calculateMonthlyPayment(principal: 100000, annualRatePercent: 5, durationMonths: 0),
        isNull,
      );
      expect(
        calculateMonthlyPayment(principal: 100000, annualRatePercent: 5, durationMonths: -3),
        isNull,
      );
    });

    test('retourne null si le taux est négatif', () {
      expect(
        calculateMonthlyPayment(principal: 100000, annualRatePercent: -1, durationMonths: 12),
        isNull,
      );
    });

    test('retourne null si un paramètre est manquant', () {
      expect(
        calculateMonthlyPayment(principal: null, annualRatePercent: 5, durationMonths: 12),
        isNull,
      );
      expect(
        calculateMonthlyPayment(principal: 100000, annualRatePercent: null, durationMonths: 12),
        isNull,
      );
      expect(
        calculateMonthlyPayment(principal: 100000, annualRatePercent: 5, durationMonths: null),
        isNull,
      );
    });

    test('mensualité × durée > capital (les intérêts sont bien inclus)', () {
      final payment = calculateMonthlyPayment(
        principal: 500000,
        annualRatePercent: 8,
        durationMonths: 24,
      );
      expect(payment! * 24, greaterThan(500000));
    });
  });
}
