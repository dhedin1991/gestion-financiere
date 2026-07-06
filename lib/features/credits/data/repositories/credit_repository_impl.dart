import '../../domain/entities/credit.dart';
import '../../domain/entities/credit_installment.dart';
import '../../domain/repositories/credit_repository.dart';
import '../datasources/credit_dao.dart';
import '../models/credit_installment_model.dart';
import '../models/credit_model.dart';

class CreditRepositoryImpl implements CreditRepository {
  final CreditDao dao;

  CreditRepositoryImpl(this.dao);

  @override
  Future<int> createCredit(Credit credit) async {
    final model = CreditModel.fromEntity(credit);
    return dao.insertCreditWithSchedule(model);
  }

  @override
  Future<int> updateCredit(Credit credit) async {
    final model = CreditModel.fromEntity(credit);
    return dao.updateCredit(model);
  }

  @override
  Future<int> deleteCredit(int id) async {
    return dao.deleteCredit(id);
  }

  @override
  Future<Credit?> getCreditById(int id) async {
    return dao.getCreditById(id);
  }

  @override
  Future<List<Credit>> getAllCredits() async {
    return dao.getAllCredits();
  }

  @override
  Future<List<CreditInstallment>> getInstallmentsForCredit(int creditId) async {
    return dao.getInstallmentsForCredit(creditId);
  }

  @override
  Future<int> updateInstallment(CreditInstallment installment) async {
    final model = CreditInstallmentModel.fromEntity(installment);
    return dao.updateInstallment(model);
  }

  @override
  Future<int> countPaidInstallments(int creditId) async {
    return dao.countPaidInstallments(creditId);
  }

  @override
  Future<double> getTotalPaidForCredit(int creditId) async {
    return dao.getTotalPaidForCredit(creditId);
  }
}
