import '../entities/recurring_transaction.dart';

abstract class RecurringTransactionRepository {
  Future<List<RecurringTransaction>> getAll();
  Future<List<RecurringTransaction>> getDue();
  Future<int> create(RecurringTransaction r);
  Future<void> update(RecurringTransaction r);
  Future<void> delete(int id);
}
