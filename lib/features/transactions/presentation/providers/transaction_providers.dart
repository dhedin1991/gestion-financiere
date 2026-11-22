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
  final accounts = await ref.watch(accountsListProvider.future);
  final accountIds = accounts.map((a) => a.id).toSet();
  final all = await repository.getTransactions(limit: 300);
  return all.where((t) => accountIds.contains(t.accountId)).take(100).toList();
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

/// Page de transactions filtrées + indicateur "il y en a d'autres".
class TransactionsPage {
  final List<FinancialTransaction> items;
  final bool hasMore;
  final bool loadingMore;

  const TransactionsPage({required this.items, required this.hasMore, this.loadingMore = false});

  TransactionsPage copyWith({List<FinancialTransaction>? items, bool? hasMore, bool? loadingMore}) {
    return TransactionsPage(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Transactions filtrées selon [transactionFiltersProvider], chargées par
/// pages de 50 (au lieu d'un plafond fixe à 300 qui cachait silencieusement
/// les transactions plus anciennes sans le dire). Se recalcule depuis le
/// début à chaque changement de filtre ; [loadMore] ajoute la page suivante.
class TransactionListNotifier extends StateNotifier<AsyncValue<TransactionsPage>> {
  TransactionListNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load(reset: true);
  }

  static const pageSize = 50;
  final Ref _ref;
  int _offset = 0;

  Future<void> _load({required bool reset}) async {
    if (reset) {
      _offset = 0;
      state = const AsyncValue.loading();
    }
    try {
      final filters = _ref.read(transactionFiltersProvider);
      final repository = _ref.read(transactionRepositoryProvider);
      final accounts = await _ref.read(accountsListProvider.future);
      final accountIds = accounts.map((a) => a.id).toSet();

      // On sur-demande un peu pour compenser les lignes filtrées ensuite
      // par accountIds (comptes archivés exclus) et garder des pages pleines.
      final fetched = await repository.getTransactions(
        accountId: filters.accountId,
        categoryId: filters.categoryId,
        type: filters.type,
        searchText: filters.search.trim().isEmpty ? null : filters.search,
        limit: pageSize,
        offset: _offset,
      );
      final page = fetched.where((t) => accountIds.contains(t.accountId)).toList();
      final hasMore = fetched.length == pageSize;
      _offset += fetched.length;

      if (!mounted) return; // le provider a été libéré pendant le chargement
      final previous = reset ? const <FinancialTransaction>[] : (state.valueOrNull?.items ?? const []);
      state = AsyncValue.data(TransactionsPage(items: [...previous, ...page], hasMore: hasMore));
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncValue.data(current.copyWith(loadingMore: true));
    await _load(reset: false);
  }

  void reset() => _load(reset: true);
}

final filteredTransactionsProvider =
    StateNotifierProvider.autoDispose<TransactionListNotifier, AsyncValue<TransactionsPage>>((ref) {
  ref.watch(transactionFiltersProvider); // reconstruit le notifier (donc réinitialise) au changement de filtre
  return TransactionListNotifier(ref);
});

/// Total des revenus du mois en cours — utile pour le Tableau de bord.
final monthlyIncomeProvider = FutureProvider.autoDispose<double>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final accounts = await ref.watch(accountsListProvider.future);
  final main = await ref.watch(mainCurrencyProvider.future);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  return repository.getTotalByType(
    TransactionType.revenu,
    from: start,
    accountIds: accounts.where((a) => a.id != null).map((a) => a.id!).toList(),
    currency: main,
  );
});

/// Total des dépenses du mois en cours.
final monthlyExpenseProvider = FutureProvider.autoDispose<double>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final accounts = await ref.watch(accountsListProvider.future);
  final main = await ref.watch(mainCurrencyProvider.future);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  return repository.getTotalByType(
    TransactionType.depense,
    from: start,
    accountIds: accounts.where((a) => a.id != null).map((a) => a.id!).toList(),
    currency: main,
  );
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
