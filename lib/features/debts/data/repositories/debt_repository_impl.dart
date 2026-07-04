import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';
import '../datasources/debt_dao.dart';
import '../models/debt_model.dart';

/// Implémentation concrète de DebtRepository.
/// C'est ici qu'on enrichit chaque Debt avec son paidAmount calculé
/// à partir des paiements enregistrés.
class DebtRepositoryImpl implements DebtRepository {
  final DebtDao _dao;

  DebtRepositoryImpl(this._dao);

  @override
  Future<List<Debt>> getAllDebts({DebtType? filterType}) async {
    final rows = await _dao.findAll();
    final debts = <Debt>[];
    for (final row in rows) {
      final paid = await _dao.sumPaymentsForDebt(row['id'] as int);
      debts.add(DebtModel.fromMap(row, paidAmount: paid));
    }
    if (filterType == null) return debts;
    return debts.where((d) => d.type == filterType).toList();
  }

  @override
  Future<Debt?> getDebtById(int id) async {
    final row = await _dao.findById(id);
    if (row == null) return null;
    final paid = await _dao.sumPaymentsForDebt(id);
    return DebtModel.fromMap(row, paidAmount: paid);
  }

  @override
  Future<Debt> createDebt(Debt debt) async {
    final now = DateTime.now();
    final toCreate = debt.copyWith(createdAt: now, updatedAt: now);
    final id = await _dao.insert(DebtModel.toMap(toCreate));
    return toCreate.copyWith(id: id);
  }

  @override
  Future<void> updateDebt(Debt debt) async {
    if (debt.id == null) {
      throw ArgumentError('Impossible de mettre à jour une dette sans id');
    }
    final updated = debt.copyWith(updatedAt: DateTime.now());
    await _dao.update(debt.id!, DebtModel.toMap(updated));
  }

  @override
  Future<void> deleteDebt(int id) async {
    await _dao.delete(id);
  }

  @override
  Future<List<DebtPayment>> getPaymentsForDebt(int debtId) async {
    final rows = await _dao.findPaymentsByDebt(debtId);
    return rows.map(DebtPaymentModel.fromMap).toList();
  }

  @override
  Future<void> addPayment(DebtPayment payment) async {
    final toCreate = DebtPayment(
      debtId: payment.debtId,
      amount: payment.amount,
      paymentDate: payment.paymentDate,
      note: payment.note,
      createdAt: DateTime.now(),
    );
    await _dao.insertPayment(DebtPaymentModel.toMap(toCreate));
  }

  @override
  Future<void> deletePayment(int paymentId, int debtId) async {
    await _dao.deletePayment(paymentId);
  }
}
