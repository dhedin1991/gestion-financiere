import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../data/datasources/debt_dao.dart';
import '../../data/repositories/debt_repository_impl.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';

final debtDaoProvider = Provider<DebtDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DebtDao(db);
});

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final dao = ref.watch(debtDaoProvider);
  return DebtRepositoryImpl(dao);
});

/// Liste de toutes les dettes/créances, rafraîchie automatiquement
/// après toute création/modification/suppression via 'ref.invalidate'.
final debtsListProvider = FutureProvider.autoDispose<List<Debt>>((ref) async {
  final repository = ref.watch(debtRepositoryProvider);
  return repository.getAllDebts();
});

/// Liste des paiements pour une dette précise (paramétré par l'id).
final debtPaymentsProvider =
    FutureProvider.autoDispose.family<List<DebtPayment>, int>((ref, debtId) async {
  final repository = ref.watch(debtRepositoryProvider);
  return repository.getPaymentsForDebt(debtId);
});

/// Contrôleur exposant les actions (créer/modifier/supprimer/payer).
final debtActionsProvider = Provider<DebtActions>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return DebtActions(ref, repository);
});

class DebtActions {
  final Ref _ref;
  final DebtRepository _repository;

  DebtActions(this._ref, this._repository);

  Future<void> create(Debt debt) async {
    await _repository.createDebt(debt);
    _refresh();
  }

  Future<void> update(Debt debt) async {
    await _repository.updateDebt(debt);
    _refresh();
  }

  Future<void> delete(int id) async {
    await _repository.deleteDebt(id);
    _refresh();
  }

  Future<void> addPayment(DebtPayment payment, Debt debt) async {
    await _repository.addPayment(payment, debt);
    _ref.invalidate(debtsListProvider);
    _ref.invalidate(debtPaymentsProvider(payment.debtId));
    if (debt.accountId != null) {
      _ref.invalidate(accountsListProvider);
      _ref.invalidate(allAccountsIncludingArchivedProvider);
      _ref.invalidate(globalBalanceProvider);
    }
  }

  Future<void> deletePayment(int paymentId, int debtId, {int? accountId}) async {
    await _repository.deletePayment(paymentId, debtId);
    _ref.invalidate(debtsListProvider);
    _ref.invalidate(debtPaymentsProvider(debtId));
    if (accountId != null) {
      _ref.invalidate(accountsListProvider);
      _ref.invalidate(allAccountsIncludingArchivedProvider);
      _ref.invalidate(globalBalanceProvider);
    }
  }

  void _refresh() {
    _ref.invalidate(debtsListProvider);
  }
}
