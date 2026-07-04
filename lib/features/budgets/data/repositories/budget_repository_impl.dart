import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/budget_dao.dart';
import '../models/budget_model.dart';

/// Implémentation concrète de BudgetRepository, qui délègue tout
/// le travail SQL au BudgetDao.
class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetDao dao;

  BudgetRepositoryImpl(this.dao);

  @override
  Future<int> createBudget(Budget budget) {
    return dao.create(BudgetModel.fromEntity(budget));
  }

  @override
  Future<int> updateBudget(Budget budget) {
    return dao.update(BudgetModel.fromEntity(budget));
  }

  @override
  Future<int> deleteBudget(int id) {
    return dao.delete(id);
  }

  @override
  Future<List<Budget>> getAllBudgets() {
    return dao.getAll();
  }

  @override
  Future<Budget?> getBudgetById(int id) {
    return dao.getById(id);
  }

  @override
  Future<double> getSpentAmount(Budget budget) {
    return dao.getSpentAmount(BudgetModel.fromEntity(budget));
  }
}
