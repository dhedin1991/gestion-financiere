import '../entities/debt.dart';

abstract class DebtRepository {
  Future<List<Debt>> getAllDebts({DebtType? filterType});
  Future<Debt?> getDebtById(int id);
  Future<Debt> createDebt(Debt debt);
  Future<void> updateDebt(Debt debt);
  Future<void> deleteDebt(int id);

  Future<List<DebtPayment>> getPaymentsForDebt(int debtId);
  Future<void> addPayment(DebtPayment payment);
  Future<void> deletePayment(int paymentId, int debtId);
}
