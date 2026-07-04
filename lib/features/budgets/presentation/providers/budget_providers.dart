import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/datasources/budget_dao.dart';
import '../../data/repositories/budget_repository_impl.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';

final budgetDaoProvider = Provider<BudgetDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BudgetDao(db);
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final dao = ref.watch(budgetDaoProvider);
  return BudgetRepositoryImpl(dao);
});

/// Liste de tous les budgets, rafraîchie automatiquement après
/// toute création/modification/suppression via 'ref.invalidate'.
final budgetsListProvider = FutureProvider.autoDispose<List<Budget>>((ref) async {
  final repository = ref.watch(budgetRepositoryProvider);
  return repository.getAllBudgets();
});

/// Montant déjà dépensé pour un budget précis (paramétré par son id).
/// Utilisé pour afficher la jauge de progression.
final budgetSpentAmountProvider =
    FutureProvider.autoDispose.family<double, int>((ref, budgetId) async {
  final repository = ref.watch(budgetRepositoryProvider);
  final budget = await repository.getBudgetById(budgetId);
  if (budget == null) return 0.0;
  return repository.getSpentAmount(budget);
});

/// Contrôleur exposant les actions (créer/modifier/supprimer un budget).
final budgetActionsProvider = Provider<BudgetActions>((ref) {
  final repository = ref.watch(budgetRepositoryProvider);
  return BudgetActions(ref, repository);
});

class BudgetActions {
  final Ref _ref;
  final BudgetRepository _repository;

  BudgetActions(this._ref, this._repository);

  Future<void> create(Budget budget) async {
    await _repository.createBudget(budget);
    _refresh();
  }

  Future<void> update(Budget budget) async {
    await _repository.updateBudget(budget);
    _refresh();
    if (budget.id != null) {
      _ref.invalidate(budgetSpentAmountProvider(budget.id!));
    }
  }

  Future<void> delete(int id) async {
    await _repository.deleteBudget(id);
    _refresh();
  }

  void _refresh() {
    _ref.invalidate(budgetsListProvider);
  }
}
