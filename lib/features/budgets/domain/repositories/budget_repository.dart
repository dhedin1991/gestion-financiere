import '../entities/budget.dart';

/// Contrat que doit respecter toute implémentation du repository Budget.
/// La couche domain ne connaît que cette interface, jamais SQLite directement.
abstract class BudgetRepository {
  Future<int> createBudget(Budget budget);
  Future<int> updateBudget(Budget budget);
  Future<int> deleteBudget(int id);
  Future<List<Budget>> getAllBudgets();
  Future<Budget?> getBudgetById(int id);

  /// Retourne le montant déjà dépensé pour un budget donné.
  Future<double> getSpentAmount(Budget budget);
}
