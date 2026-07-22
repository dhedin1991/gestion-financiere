import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:gestion_financiere/features/transactions/domain/entities/transaction.dart';

RecurringTransaction _make({
  required RecurrenceFrequency frequency,
  required DateTime nextDueDate,
}) {
  final now = DateTime(2026, 1, 1);
  return RecurringTransaction(
    accountId: 1,
    type: TransactionType.depense,
    amount: 1000,
    frequency: frequency,
    nextDueDate: nextDueDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('RecurringTransaction.computeNextDueDate', () {
    test('hebdomadaire : ajoute 7 jours', () {
      final r = _make(frequency: RecurrenceFrequency.hebdomadaire, nextDueDate: DateTime(2026, 3, 10));
      expect(r.computeNextDueDate(), DateTime(2026, 3, 17));
    });

    test('mensuelle : passe au mois suivant, même jour', () {
      final r = _make(frequency: RecurrenceFrequency.mensuelle, nextDueDate: DateTime(2026, 3, 15));
      expect(r.computeNextDueDate(), DateTime(2026, 4, 15));
    });

    test('mensuelle : franchit le passage d\'année (décembre -> janvier)', () {
      final r = _make(frequency: RecurrenceFrequency.mensuelle, nextDueDate: DateTime(2026, 12, 5));
      expect(r.computeNextDueDate(), DateTime(2027, 1, 5));
    });

    test('annuelle : ajoute un an, même jour et mois', () {
      final r = _make(frequency: RecurrenceFrequency.annuelle, nextDueDate: DateTime(2026, 6, 20));
      expect(r.computeNextDueDate(), DateTime(2027, 6, 20));
    });
  });
}
