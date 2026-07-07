import '../../domain/entities/savings.dart';
import '../../domain/repositories/savings_repository.dart';
import '../datasources/savings_dao.dart';
import '../models/savings_model.dart';

class SavingsRepositoryImpl implements SavingsRepository {
  final SavingsDao _dao;

  SavingsRepositoryImpl(this._dao);

  @override
  Future<List<Savings>> getAllSavings() async {
    final rows = await _dao.findAll();
    return rows.map(SavingsModel.fromMap).toList();
  }

  @override
  Future<Savings?> getSavingsById(int id) async {
    final row = await _dao.findById(id);
    if (row == null) return null;
    return SavingsModel.fromMap(row);
  }

  @override
  Future<Savings> createSavings(Savings savings) async {
    final now = DateTime.now();
    final toCreate = savings.copyWith(createdAt: now, updatedAt: now);
    final id = await _dao.insert(SavingsModel.toMap(toCreate));
    return toCreate.copyWith(id: id);
  }

  @override
  Future<void> updateSavings(Savings savings) async {
    if (savings.id == null) {
      throw ArgumentError('Impossible de mettre à jour une épargne sans id');
    }
    final updated = savings.copyWith(updatedAt: DateTime.now());
    await _dao.update(savings.id!, SavingsModel.toMap(updated));
  }

  @override
  Future<void> deleteSavings(int id) async {
    await _dao.delete(id);
  }

  @override
  Future<List<SavingsTransaction>> getTransactionsForSavings(int savingsId) async {
    final rows = await _dao.findTransactionsBySavings(savingsId);
    return rows.map(SavingsTransactionModel.fromMap).toList();
  }

  @override
  Future<void> addSavingsTransaction(SavingsTransaction transaction) async {
    final savingsRow = await _dao.findById(transaction.savingsId);
    if (savingsRow == null) {
      throw StateError('Épargne introuvable');
    }
    final savings = SavingsModel.fromMap(savingsRow);

    final toCreate = SavingsTransaction(
      savingsId: transaction.savingsId,
      type: transaction.type,
      amount: transaction.amount,
      date: transaction.date,
      note: transaction.note,
      createdAt: DateTime.now(),
    );

    await _dao.insertTransactionWithBalanceUpdate(
      data: SavingsTransactionModel.toMap(toCreate),
      savingsId: transaction.savingsId,
      accountId: savings.accountId,
      signedAmount: toCreate.signedAmount,
    );
  }

  @override
  Future<void> updateSavingsTransaction(SavingsTransaction transaction) async {
    if (transaction.id == null) {
      throw ArgumentError('Impossible de mettre à jour un mouvement sans id');
    }

    final savingsRow = await _dao.findById(transaction.savingsId);
    if (savingsRow == null) {
      throw StateError('Épargne introuvable');
    }
    final savings = SavingsModel.fromMap(savingsRow);

    final transactions = await _dao.findTransactionsBySavings(transaction.savingsId);
    final oldRowMap = transactions.firstWhere((t) => t['id'] == transaction.id);
    final oldTransaction = SavingsTransactionModel.fromMap(oldRowMap);

    final updated = SavingsTransaction(
      id: transaction.id,
      savingsId: transaction.savingsId,
      type: transaction.type,
      amount: transaction.amount,
      date: transaction.date,
      note: transaction.note,
      createdAt: oldTransaction.createdAt,
    );

    await _dao.updateTransactionWithBalanceUpdate(
      transactionId: transaction.id!,
      data: SavingsTransactionModel.toMap(updated),
      savingsId: transaction.savingsId,
      accountId: savings.accountId,
      oldSignedAmount: oldTransaction.signedAmount,
      newSignedAmount: updated.signedAmount,
    );
  }

  @override
  Future<void> deleteSavingsTransaction(int transactionId, int savingsId) async {
    final savingsRow = await _dao.findById(savingsId);
    if (savingsRow == null) {
      throw StateError('Épargne introuvable');
    }
    final savings = SavingsModel.fromMap(savingsRow);

    final transactions = await _dao.findTransactionsBySavings(savingsId);
    final rowMap = transactions.firstWhere((t) => t['id'] == transactionId);
    final transaction = SavingsTransactionModel.fromMap(rowMap);

    await _dao.deleteTransactionWithBalanceUpdate(
      transactionId: transactionId,
      savingsId: savingsId,
      accountId: savings.accountId,
      signedAmount: transaction.signedAmount,
    );
  }
}
