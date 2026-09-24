import '../entities/transaction.dart';

abstract class TransactionRepository {
  Future<List<FinancialTransaction>> getTransactions({
    int? accountId,
    int? categoryId,
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    String? searchText,
    int limit = 100,
    int offset = 0,
  });
  Future<FinancialTransaction> createTransaction(FinancialTransaction transaction);
  Future<void> updateTransaction(FinancialTransaction transaction);
  Future<void> deleteTransaction(int id);

  /// Crée un virement entre deux comptes (une dépense sur [fromAccountId],
  /// un revenu sur [toAccountId], liés). N'entre jamais dans les totaux
  /// Revenus/Dépenses.
  Future<void> createTransfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required String currency,
    required DateTime date,
    String? description,
  });

  /// Supprime un virement entier (ses deux écritures liées), identifié par
  /// le `transferGroup` de l'une de ses deux transactions.
  Future<void> deleteTransfer(int transferGroup);
  Future<double> getTotalByType(
    TransactionType type, {
    DateTime? from,
    DateTime? to,
    List<int>? accountIds,
    String? currency,
  });
}
