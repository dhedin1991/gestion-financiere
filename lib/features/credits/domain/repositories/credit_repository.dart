import '../entities/credit.dart';
import '../entities/credit_installment.dart';

abstract class CreditRepository {
  Future<int> createCredit(Credit credit);

  Future<int> updateCredit(Credit credit);

  Future<int> deleteCredit(int id);

  Future<Credit?> getCreditById(int id);

  Future<List<Credit>> getAllCredits();

  Future<List<CreditInstallment>> getInstallmentsForCredit(int creditId);

  Future<int> updateInstallment(CreditInstallment installment);

  Future<int> countPaidInstallments(int creditId);

  Future<double> getTotalPaidForCredit(int creditId);
}
