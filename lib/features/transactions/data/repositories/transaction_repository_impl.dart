import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_dao.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionDao _dao;
  TransactionRepositoryImpl(this._dao);

  @override
  Future<List<FinancialTransaction>> getTransactions({
    int? accountId,
    int? categoryId,
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    String? searchText,
    int limit = 100,
  }) async {
    final rows = await _dao.find(
      accountId: accountId,
      categoryId: categoryId,
      type: type == null ? null : (type == TransactionType.revenu ? 'revenu' : 'depense'),
      fromIso: from?.toIso8601String(),
      toIso: to?.toIso8601String(),
      searchText: searchText,
      limit: limit,
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  @override
  Future<FinancialTransaction> createTransaction(FinancialTransaction transaction) async {
    final now = DateTime.now();
    final toCreate = transaction.copyWith(createdAt: now, updatedAt: now);
    final id = await _dao.insertWithBalanceUpdate(
      TransactionModel.toMap(toCreate),
      toCreate.signedAmount,
    );
    return toCreate.copyWith(id: id);
  }

  @override
  Future<void> updateTransaction(FinancialTransaction transaction) async {
    if (transaction.id == null) {
      throw ArgumentError('Impossible de modifier une transaction sans id');
    }
    final oldRow = await _dao.findById(transaction.id!);
    if (oldRow == null) {
      throw StateError('Transaction introuvable');
    }
    final old = TransactionModel.fromMap(oldRow);
    final updated = transaction.copyWith(updatedAt: DateTime.now());

    await _dao.updateWithBalanceUpdate(
      id: transaction.id!,
      newData: TransactionModel.toMap(updated),
      oldAccountId: old.accountId,
      oldSignedAmount: old.signedAmount,
      newAccountId: updated.accountId,
      newSignedAmount: updated.signedAmount,
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final row = await _dao.findById(id);
    if (row == null) return;
    final t = TransactionModel.fromMap(row);
    await _dao.deleteWithBalanceUpdate(id, t.accountId, t.signedAmount);
  }

  @override
  Future<double> getTotalByType(TransactionType type, {DateTime? from, DateTime? to}) {
    return _dao.sumByType(
      type == TransactionType.revenu ? 'revenu' : 'depense',
      fromIso: from?.toIso8601String(),
      toIso: to?.toIso8601String(),
    );
  }
}
