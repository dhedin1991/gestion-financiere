import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/utils/loan_calculator.dart';

void main() {
  group('calculateMonthlyPayment', () {
    test('la mensualité amortit exactement le capital sur la durée', () {
      // Vérification indépendante de la formule : si on simule
      // l'amortissement mois par mois avec la mensualité calculée,
      // le solde restant doit tomber à ~0 à la fin de la durée.
      const principal = 1000000.0;
      const annualRate = 12.0;
      const duration = 12;

      final payment = calculateMonthlyPayment(
        principal: principal,
        annualRatePercent: annualRate,
        durationMonths: duration,
      )!;

      final monthlyRate = annualRate / 100 / 12;
      var balance = principal;
      for (var i = 0; i < duration; i++) {
        balance = balance * (1 + monthlyRate) - payment;
      }

      expect(balance, closeTo(0, 0.5));
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
