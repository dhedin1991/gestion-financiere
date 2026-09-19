import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:gestion_financiere/features/transactions/domain/entities/transaction.dart';

RecurringTransaction _monthly(DateTime next, {int? anchorDay}) {
  final now = DateTime(2026, 1, 1);
  return RecurringTransaction(
    accountId: 1,
    type: TransactionType.depense,
    amount: 1000,
    frequency: RecurrenceFrequency.mensuelle,
    nextDueDate: next,
    anchorDay: anchorDay,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('une récurrence mensuelle au 31 ne saute jamais de mois et ne dérive pas', () {
    var r = _monthly(DateTime(2026, 1, 31), anchorDay: 31);
    final dates = <DateTime>[];
    for (var i = 0; i < 5; i++) {
      final next = r.computeNextDueDate();
      dates.add(next);
      r = r.copyWith(nextDueDate: next);
    }
    expect(dates, [
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
      DateTime(2026, 4, 30),
      DateTime(2026, 5, 31),
      DateTime(2026, 6, 30),
    ]);
  });

  test('sans jour d\'ancrage (anciennes données), pas de saut de mois', () {
    final r = _monthly(DateTime(2026, 1, 31));
    expect(r.computeNextDueDate(), DateTime(2026, 2, 28));
  });
}
