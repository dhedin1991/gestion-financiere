import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/datasources/savings_dao.dart';
import '../../data/repositories/savings_repository_impl.dart';
import '../../domain/entities/savings.dart';
import '../../domain/repositories/savings_repository.dart';

final savingsDaoProvider = Provider<SavingsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SavingsDao(db);
});

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  final dao = ref.watch(savingsDaoProvider);
  return SavingsRepositoryImpl(dao);
});

/// Liste de toutes les épargnes, rafraîchie automatiquement après
/// toute création/modification/suppression via 'ref.invalidate'.
final savingsListProvider = FutureProvider.autoDispose<List<Savings>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getAllSavings();
});

/// Historique des mouvements (versements/retraits) d'une épargne précise
/// (paramétré par son id).
final savingsTransactionsProvider =
    FutureProvider.autoDispose.family<List<SavingsTransaction>, int>((ref, savingsId) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getTransactionsForSavings(savingsId);
});

/// Contrôleur exposant les actions (créer/modifier/supprimer une épargne,
/// verser/retirer de l'argent).
final savingsActionsProvider = Provider<SavingsActions>((ref) {
  final repository = ref.watch(savingsRepositoryProvider);
  return SavingsActions(ref, repository);
});

class SavingsActions {
  final Ref _ref;
  final SavingsRepository _repository;

  SavingsActions(this._ref, this._repository);

  Future<void> create(Savings savings) async {
    await _repository.createSavings(savings);
    _refresh();
  }

  Future<void> update(Savings savings) async {
    await _repository.updateSavings(savings);
    _refresh();
  }

  Future<void> delete(int id) async {
    await _repository.deleteSavings(id);
    _refresh();
  }

  Future<void> addTransaction(SavingsTransaction transaction) async {
    await _repository.addSavingsTransaction(transaction);
    _refresh();
    _ref.invalidate(savingsTransactionsProvider(transaction.savingsId));
  }

  Future<void> updateTransaction(SavingsTransaction transaction) async {
    await _repository.updateSavingsTransaction(transaction);
    _refresh();
    _ref.invalidate(savingsTransactionsProvider(transaction.savingsId));
  }

  Future<void> deleteTransaction(int transactionId, int savingsId) async {
    await _repository.deleteSavingsTransaction(transactionId, savingsId);
    _refresh();
    _ref.invalidate(savingsTransactionsProvider(savingsId));
  }

  void _refresh() {
    _ref.invalidate(savingsListProvider);
  }
}
