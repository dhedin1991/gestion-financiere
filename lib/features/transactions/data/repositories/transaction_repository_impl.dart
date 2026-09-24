import '../../../../core/utils/money.dart';
import '../../../audit_log/data/audit_log_dao.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_dao.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionDao _dao;
  final AuditLogDao? _auditLog;
  TransactionRepositoryImpl(this._dao, [this._auditLog]);

  @override
  Future<List<FinancialTransaction>> getTransactions({
    int? accountId,
    int? categoryId,
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    String? searchText,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _dao.find(
      accountId: accountId,
      categoryId: categoryId,
      type: type == null ? null : (type == TransactionType.revenu ? 'revenu' : 'depense'),
      fromIso: from?.toIso8601String(),
      toIso: to?.toIso8601String(),
      searchText: searchText,
      limit: limit,
      offset: offset,
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
    await _auditLog?.log(
      entityType: 'transaction',
      entityId: id,
      action: 'create',
      newValue: '${toCreate.type == TransactionType.revenu ? '+' : '-'}${toCreate.amount} ${toCreate.currency}'
          '${toCreate.description != null ? ' — ${toCreate.description}' : ''}',
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
    await _auditLog?.log(
      entityType: 'transaction',
      entityId: transaction.id!,
      action: 'update',
      oldValue: '${old.amount} ${old.currency}',
      newValue: '${updated.amount} ${updated.currency}',
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final row = await _dao.findById(id);
    if (row == null) return;
    final t = TransactionModel.fromMap(row);
    if (t.isTransfer) {
      // Une moitié de virement ne se supprime jamais seule : les deux
      // écritures doivent rester cohérentes entre elles.
      await deleteTransfer(t.transferGroup!);
      return;
    }
    await _dao.deleteWithBalanceUpdate(id, t.accountId, t.signedAmount);
    await _auditLog?.log(
      entityType: 'transaction',
      entityId: id,
      action: 'delete',
      oldValue: '${t.amount} ${t.currency}${t.description != null ? ' — ${t.description}' : ''}',
    );
  }

  @override
  Future<void> createTransfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required String currency,
    required DateTime date,
    String? description,
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Le compte source et le compte destination doivent être différents.');
    }
    if (amount <= 0) {
      throw ArgumentError('Le montant du virement doit être supérieur à 0.');
    }
    final now = DateTime.now();
    final amountCents = Money.toCents(amount);
    final label = description == null || description.trim().isEmpty
        ? 'Virement'
        : 'Virement — ${description.trim()}';

    final depenseData = TransactionModel.toMap(FinancialTransaction(
      accountId: fromAccountId,
      type: TransactionType.depense,
      amount: amount,
      currency: currency,
      description: label,
      transactionDate: date,
      createdAt: now,
      updatedAt: now,
    ));
    final revenuData = TransactionModel.toMap(FinancialTransaction(
      accountId: toAccountId,
      type: TransactionType.revenu,
      amount: amount,
      currency: currency,
      description: label,
      transactionDate: date,
      createdAt: now,
      updatedAt: now,
    ));

    final (depenseId, _) = await _dao.insertTransfer(
      depenseData: depenseData,
      revenuData: revenuData,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amountCents: amountCents,
    );

    await _auditLog?.log(
      entityType: 'transaction',
      entityId: depenseId,
      action: 'create',
      newValue: 'Virement de $amount $currency (compte $fromAccountId -> compte $toAccountId)',
    );
  }

  @override
  Future<void> deleteTransfer(int transferGroup) async {
    await _dao.deleteTransfer(transferGroup);
    await _auditLog?.log(
      entityType: 'transaction',
      entityId: transferGroup,
      action: 'delete',
      oldValue: 'Virement supprimé',
    );
  }

  @override
  Future<double> getTotalByType(
    TransactionType type, {
    DateTime? from,
    DateTime? to,
    List<int>? accountIds,
    String? currency,
  }) {
    return _dao.sumByType(
      type == TransactionType.revenu ? 'revenu' : 'depense',
      fromIso: from?.toIso8601String(),
      toIso: to?.toIso8601String(),
      accountIds: accountIds,
      currency: currency,
    );
  }
}
