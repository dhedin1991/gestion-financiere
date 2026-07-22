import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/features/debts/domain/entities/debt.dart';

Debt _makeDebt({required double totalAmount, double paidAmount = 0}) {
  final now = DateTime(2026, 1, 1);
  return Debt(
    type: DebtType.dette,
    personName: 'Test',
    totalAmount: totalAmount,
    createdAt: now,
    updatedAt: now,
    paidAmount: paidAmount,
  );
}

void main() {
  group('Debt', () {
    test('remainingAmount = totalAmount - paidAmount', () {
      final debt = _makeDebt(totalAmount: 100000, paidAmount: 30000);
      expect(debt.remainingAmount, 70000);
    });

    test('isSettled est faux tant qu\'il reste un solde', () {
      final debt = _makeDebt(totalAmount: 100000, paidAmount: 30000);
      expect(debt.isSettled, isFalse);
    });

    test('isSettled est vrai quand tout est payé', () {
      final debt = _makeDebt(totalAmount: 100000, paidAmount: 100000);
      expect(debt.isSettled, isTrue);
    });

    test('isSettled tolère une infime erreur d\'arrondi flottant', () {
      // 0.1 + 0.2 en flottant ne fait pas exactement 0.3 : la dette doit
      // quand même être considérée soldée si l'écart est négligeable.
      final debt = _makeDebt(totalAmount: 0.3, paidAmount: 0.1 + 0.2);
      expect(debt.isSettled, isTrue);
    });

    test('remainingAmount peut être négatif en cas de trop-perçu', () {
      final debt = _makeDebt(totalAmount: 100000, paidAmount: 105000);
      expect(debt.remainingAmount, -5000);
      expect(debt.isSettled, isTrue);
    });
  });
}
