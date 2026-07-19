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
    final debtRow = await _dao.findById(id);
    final accountId = debtRow?['account_id'] as int?;

    if (debtRow != null && accountId != null) {
      final paid = await _dao.sumPaymentsForDebt(id);
      if (paid > 0) {
        final type = (debtRow['type'] as String) == 'creance' ? DebtType.creance : DebtType.dette;
        // Effet déjà appliqué au compte par les paiements passés :
        final appliedSigned = type == DebtType.dette ? -paid : paid;
        // On annule cet effet en appliquant le montant opposé.
        await _dao.deleteDebtWithBalanceReversal(
          debtId: id,
          accountId: accountId,
          reversalAmount: -appliedSigned,
        );
        return;
      }
    }
    await _dao.delete(id);
  }

  @override
  Future<List<DebtPayment>> getPaymentsForDebt(int debtId) async {
    final rows = await _dao.findPaymentsByDebt(debtId);
    return rows.map(DebtPaymentModel.fromMap).toList();
  }

  @override
  Future<void> addPayment(DebtPayment payment, Debt debt) async {
    final toCreate = DebtPayment(
      debtId: payment.debtId,
      amount: payment.amount,
      paymentDate: payment.paymentDate,
      note: payment.note,
      createdAt: DateTime.now(),
    );
    final data = DebtPaymentModel.toMap(toCreate);

    if (debt.accountId != null) {
      // Dette ("je dois") : l'argent sort du compte -> montant négatif.
      // Créance ("on me doit") : l'argent entre sur le compte -> montant positif.
      final signedAmount = debt.type == DebtType.dette ? -payment.amount : payment.amount;
      await _dao.insertPaymentWithBalanceUpdate(
        data: data,
        accountId: debt.accountId!,
        signedAmount: signedAmount,
      );
    } else {
      // Aucun compte lié : comportement historique, on enregistre juste le paiement.
      await _dao.insertPayment(data);
    }
  }

  @override
  Future<void> deletePayment(int paymentId, int debtId) async {
    final debtRow = await _dao.findById(debtId);
    final paymentRow = await _dao.findPaymentById(paymentId);
    final accountId = debtRow?['account_id'] as int?;

    if (debtRow != null && paymentRow != null && accountId != null) {
      final type = (debtRow['type'] as String) == 'creance' ? DebtType.creance : DebtType.dette;
      final amount = (paymentRow['amount'] as num).toDouble();
      final signedAmount = type == DebtType.dette ? -amount : amount;
      await _dao.deletePaymentWithBalanceUpdate(
        paymentId: paymentId,
        accountId: accountId,
        signedAmount: signedAmount,
      );
    } else {
      await _dao.deletePayment(paymentId);
    }
  }
}
