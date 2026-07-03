import '../entities/transaction.dart';

abstract class TransactionRepository {
  Future<List<FinancialTransaction>> getTransactions({
    int? accountId,
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  });
  Future<FinancialTransaction> createTransaction(FinancialTransaction transaction);
  Future<void> updateTransaction(FinancialTransaction transaction);
  Future<void> deleteTransaction(int id);
  Future<double> getTotalByType(TransactionType type, {DateTime? from, DateTime? to});
}
