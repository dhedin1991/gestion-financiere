import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/datasources/recurring_transaction_dao.dart';
import '../../data/recurring_transaction_generator.dart';
import '../../data/repositories/recurring_transaction_repository_impl.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../../domain/repositories/recurring_transaction_repository.dart';

final recurringTransactionDaoProvider = Provider<RecurringTransactionDao>((ref) {
  return RecurringTransactionDao(ref.watch(appDatabaseProvider));
});

final recurringTransactionRepositoryProvider = Provider<RecurringTransactionRepository>((ref) {
  return RecurringTransactionRepositoryImpl(ref.watch(recurringTransactionDaoProvider));
});

final recurringTransactionGeneratorProvider = Provider<RecurringTransactionGenerator>((ref) {
  return RecurringTransactionGenerator(
    recurringRepository: ref.watch(recurringTransactionRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});

final allRecurringTransactionsProvider =
    FutureProvider.autoDispose<List<RecurringTransaction>>((ref) async {
  return ref.watch(recurringTransactionRepositoryProvider).getAll();
});

/// Génère les transactions dues une seule fois au démarrage de l'app (lu
/// depuis main.dart, comme reminderBootstrapProvider). `keepAlive` pour
/// ne pas relancer la génération à chaque rebuild.
final recurringGenerationBootstrapProvider = FutureProvider<void>((ref) async {
  ref.keepAlive();
  final count = await ref.watch(recurringTransactionGeneratorProvider).generateDueTransactions();
  if (count > 0) {
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(filteredTransactionsProvider);
    ref.invalidate(monthlyIncomeProvider);
    ref.invalidate(monthlyExpenseProvider);
    ref.invalidate(accountsListProvider);
    ref.invalidate(globalBalanceProvider);
  }
});

final recurringActionsProvider = Provider<RecurringActions>((ref) {
  return RecurringActions(ref, ref.watch(recurringTransactionRepositoryProvider));
});

class RecurringActions {
  final Ref _ref;
  final RecurringTransactionRepository _repository;
  RecurringActions(this._ref, this._repository);

  Future<void> create(RecurringTransaction r) async {
    await _repository.create(r);
    _ref.invalidate(allRecurringTransactionsProvider);
  }

  Future<void> update(RecurringTransaction r) async {
    await _repository.update(r);
    _ref.invalidate(allRecurringTransactionsProvider);
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    _ref.invalidate(allRecurringTransactionsProvider);
  }
}
