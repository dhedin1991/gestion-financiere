import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/features/recurring/data/recurring_transaction_generator.dart';
import 'package:gestion_financiere/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:gestion_financiere/features/recurring/domain/repositories/recurring_transaction_repository.dart';
import 'package:gestion_financiere/features/transactions/domain/entities/transaction.dart';
import 'package:gestion_financiere/features/transactions/domain/repositories/transaction_repository.dart';

class _FakeRecurringRepository implements RecurringTransactionRepository {
  final List<RecurringTransaction> items;
  final List<RecurringTransaction> updated = [];
  _FakeRecurringRepository(this.items);

  @override
  Future<List<RecurringTransaction>> getAll() async => items;

  @override
  Future<List<RecurringTransaction>> getDue() async {
    final now = DateTime.now();
    return items.where((r) => r.active && !r.nextDueDate.isAfter(now)).toList();
  }

  @override
  Future<int> create(RecurringTransaction r) async => 1;

  @override
  Future<void> update(RecurringTransaction r) async => updated.add(r);

  @override
  Future<void> delete(int id) async {}
}

class _FakeTransactionRepository implements TransactionRepository {
  final List<FinancialTransaction> created = [];

  @override
  Future<FinancialTransaction> createTransaction(FinancialTransaction t) async {
    created.add(t);
    return t.copyWith(id: created.length);
  }

  @override
  Future<List<FinancialTransaction>> getTransactions({
    int? accountId,
    int? categoryId,
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    String? searchText,
    int limit = 100,
  }) async =>
      created;

  @override
  Future<void> updateTransaction(FinancialTransaction transaction) async {}

  @override
  Future<void> deleteTransaction(int id) async {}

  @override
  Future<double> getTotalByType(TransactionType type, {DateTime? from, DateTime? to}) async => 0;
}

RecurringTransaction _make({
  required RecurrenceFrequency frequency,
  required DateTime nextDueDate,
  bool active = true,
}) {
  final now = DateTime(2026, 1, 1);
  return RecurringTransaction(
    id: 1,
    accountId: 1,
    type: TransactionType.depense,
    amount: 5000,
    frequency: frequency,
    nextDueDate: nextDueDate,
    active: active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('RecurringTransactionGenerator', () {
    test('génère une transaction pour une échéance passée d\'un jour', () async {
      final recurringRepo = _FakeRecurringRepository([
        _make(
          frequency: RecurrenceFrequency.mensuelle,
          nextDueDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]);
      final txRepo = _FakeTransactionRepository();
      final generator = RecurringTransactionGenerator(
        recurringRepository: recurringRepo,
        transactionRepository: txRepo,
      );

      final count = await generator.generateDueTransactions();

      expect(count, 1);
      expect(txRepo.created.length, 1);
      expect(recurringRepo.updated.length, 1);
      expect(recurringRepo.updated.first.nextDueDate.isAfter(DateTime.now()), isTrue);
    });

    test('ne génère rien pour une échéance future', () async {
      final recurringRepo = _FakeRecurringRepository([
        _make(
          frequency: RecurrenceFrequency.mensuelle,
          nextDueDate: DateTime.now().add(const Duration(days: 10)),
        ),
      ]);
      final txRepo = _FakeTransactionRepository();
      final generator = RecurringTransactionGenerator(
        recurringRepository: recurringRepo,
        transactionRepository: txRepo,
      );

      final count = await generator.generateDueTransactions();

      expect(count, 0);
      expect(txRepo.created, isEmpty);
    });

    test('rattrape plusieurs échéances hebdomadaires manquées', () async {
      // 20 jours (pas un multiple exact de 7) pour éviter l'ambiguïté de
      // bord : à exactement 21 jours (3×7), la 3e avance retombe pile sur
      // "maintenant", ce qui déclenche légitimement une 4e occurrence.
      final recurringRepo = _FakeRecurringRepository([
        _make(
          frequency: RecurrenceFrequency.hebdomadaire,
          nextDueDate: DateTime.now().subtract(const Duration(days: 20)),
        ),
      ]);
      final txRepo = _FakeTransactionRepository();
      final generator = RecurringTransactionGenerator(
        recurringRepository: recurringRepo,
        transactionRepository: txRepo,
      );

      final count = await generator.generateDueTransactions();

      expect(count, 3);
      expect(txRepo.created.length, 3);
    });

    test('ignore une récurrence inactive même en retard', () async {
      final recurringRepo = _FakeRecurringRepository([
        _make(
          frequency: RecurrenceFrequency.mensuelle,
          nextDueDate: DateTime.now().subtract(const Duration(days: 60)),
          active: false,
        ),
      ]);
      final txRepo = _FakeTransactionRepository();
      final generator = RecurringTransactionGenerator(
        recurringRepository: recurringRepo,
        transactionRepository: txRepo,
      );

      final count = await generator.generateDueTransactions();

      expect(count, 0);
    });
  });
}
