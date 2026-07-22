import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/features/savings/domain/entities/savings.dart';

Savings _makeSavings({double currentBalance = 0, double? targetAmount}) {
  final now = DateTime(2026, 1, 1);
  return Savings(
    name: 'Test',
    accountId: 1,
    currentBalance: currentBalance,
    targetAmount: targetAmount,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Savings', () {
    test('hasTarget est faux sans montant cible', () {
      expect(_makeSavings().hasTarget, isFalse);
    });

    test('hasTarget est faux si le montant cible est 0', () {
      expect(_makeSavings(targetAmount: 0).hasTarget, isFalse);
    });

    test('progress est null sans objectif', () {
      expect(_makeSavings(currentBalance: 5000).progress, isNull);
    });

    test('progress calcule correctement le ratio', () {
      final s = _makeSavings(currentBalance: 25000, targetAmount: 100000);
      expect(s.progress, 0.25);
    });

    test('progress est plafonné à 1.0 même si l\'objectif est dépassé', () {
      final s = _makeSavings(currentBalance: 150000, targetAmount: 100000);
      expect(s.progress, 1.0);
    });

    test('progress est plancher à 0.0 (jamais négatif)', () {
      final s = _makeSavings(currentBalance: -5000, targetAmount: 100000);
      expect(s.progress, 0.0);
    });
  });
}
