import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../audit_log/presentation/providers/audit_log_providers.dart';
import '../../data/datasources/transaction_dao.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

final transactionDaoProvider = Provider<TransactionDao>((ref) {
  return TransactionDao(ref.watch(appDatabaseProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(transactionDaoProvider), ref.watch(auditLogDaoProvider));
});

/// Les 100 dernières transactions, toutes confondues (utilisé par l'écran
/// "Revenus & Dépenses"). Peut être filtré plus tard par compte/période.
final recentTransactionsProvider =
    FutureProvider.autoDispose<List<FinancialTransaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getTransactions(limit: 100);
});

/// Critères de recherche/filtre appliqués à la liste des transactions.
/// Tout champ null = pas de filtre sur ce critère.
class TransactionFilters {
  final String search;
  final int? accountId;
  final int? categoryId;
  final TransactionType? type;

  const TransactionFilters({
    this.search = '',
    this.accountId,
    this.categoryId,
    this.type,
  });

  bool get isActive =>
      search.trim().isNotEmpty || accountId != null || categoryId != null || type != null;

  TransactionFilters copyWith({
    String? search,
    int? Function()? accountId,
    int? Function()? categoryId,
    TransactionType? Function()? type,
  }) {
    return TransactionFilters(
      search: search ?? this.search,
      accountId: accountId != null ? accountId() : this.accountId,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      type: type != null ? type() : this.type,
    );
  }
}

final transactionFiltersProvider = StateProvider.autoDispose<TransactionFilters>((ref) {
  return const TransactionFilters();
});

/// Transactions filtrées selon [transactionFiltersProvider]. Se
/// recalcule automatiquement à chaque changement de filtre.
final filteredTransactionsProvider =
    FutureProvider.autoDispose<List<FinancialTransaction>>((ref) async {
  final filters = ref.watch(transactionFiltersProvider);
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getTransactions(
    accountId: filters.accountId,
    categoryId: filters.categoryId,
    type: filters.type,
    searchText: filters.search.trim().isEmpty ? null : filters.search,
    limit: 300,
  );
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
    _ref.invalidate(filteredTransactionsProvider);
    _ref.invalidate(monthlyIncomeProvider);
    _ref.invalidate(monthlyExpenseProvider);
    _ref.invalidate(accountsListProvider);
    _ref.invalidate(globalBalanceProvider);
  }
}
