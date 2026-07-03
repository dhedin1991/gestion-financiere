import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../data/datasources/transaction_dao.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

final transactionDaoProvider = Provider<TransactionDao>((ref) {
  return TransactionDao(ref.watch(appDatabaseProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(transactionDaoProvider));
});

/// Les 100 dernières transactions, toutes confondues (utilisé par l'écran
/// "Revenus & Dépenses"). Peut être filtré plus tard par compte/période.
final recentTransactionsProvider =
    FutureProvider.autoDispose<List<FinancialTransaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getTransactions(limit: 100);
});

/// Total des revenus du mois en cours — utile pour le Tableau de bord.
final monthlyIncomeProvider = FutureProvider.autoDispose<double>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  return repository.getTotalByType(TransactionType.revenu, from: start);
});

/// Total des dépenses du mois en cours.
final monthlyExpenseProvider = FutureProvider.autoDispose<double>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  return repository.getTotalByType(TransactionType.depense, from: start);
});

final transactionActionsProvider = Provider<TransactionActions>((ref) {
  return TransactionActions(ref, ref.watch(transactionRepositoryProvider));
});

class TransactionActions {
  final Ref _ref;
  final TransactionRepository _repository;
  TransactionActions(this._ref, this._repository);

  Future<void> create(FinancialTransaction t) async {
    await _repository.createTransaction(t);
    _refresh();
  }

  Future<void> update(FinancialTransaction t) async {
    await _repository.updateTransaction(t);
    _refresh();
  }

  Future<void> delete(int id) async {
    await _repository.deleteTransaction(id);
    _refresh();
  }

  void _refresh() {
    // Une transaction impacte à la fois les listes de transactions
    // ET les soldes des comptes (Dashboard) -> on invalide les deux familles.
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(monthlyIncomeProvider);
    _ref.invalidate(monthlyExpenseProvider);
    _ref.invalidate(accountsListProvider);
    _ref.invalidate(globalBalanceProvider);
  }
}
