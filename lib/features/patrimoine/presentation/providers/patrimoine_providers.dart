import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/datasources/patrimoine_dao.dart';
import '../../data/repositories/patrimoine_repository_impl.dart';
import '../../domain/entities/patrimoine_item.dart';
import '../../domain/repositories/patrimoine_repository.dart';

final patrimoineDaoProvider = Provider<PatrimoineDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PatrimoineDao(db);
});

final patrimoineRepositoryProvider = Provider<PatrimoineRepository>((ref) {
  final dao = ref.watch(patrimoineDaoProvider);
  return PatrimoineRepositoryImpl(dao);
});

/// Liste de tous les biens, rafraîchie automatiquement après toute
/// création/modification/suppression via 'ref.invalidate'.
final patrimoineListProvider = FutureProvider.autoDispose<List<PatrimoineItem>>((ref) async {
  final repository = ref.watch(patrimoineRepositoryProvider);
  return repository.getAllItems();
});

/// Valeur totale du patrimoine (somme de tous les biens).
final patrimoineTotalValueProvider = FutureProvider.autoDispose<double>((ref) async {
  final repository = ref.watch(patrimoineRepositoryProvider);
  return repository.getTotalValue();
});

/// Contrôleur exposant les actions (créer/modifier/supprimer un bien).
final patrimoineActionsProvider = Provider<PatrimoineActions>((ref) {
  final repository = ref.watch(patrimoineRepositoryProvider);
  return PatrimoineActions(ref, repository);
});

class PatrimoineActions {
  final Ref _ref;
  final PatrimoineRepository _repository;

  PatrimoineActions(this._ref, this._repository);

  Future<void> create(PatrimoineItem item) async {
    final now = DateTime.now();
    final toSave = item.copyWith(createdAt: now, updatedAt: now);
    await _repository.addItem(toSave);
    _refresh();
  }

  Future<void> update(PatrimoineItem item) async {
    final toSave = item.copyWith(updatedAt: DateTime.now());
    await _repository.updateItem(toSave);
    _refresh();
  }

  Future<void> delete(int id) async {
    await _repository.deleteItem(id);
    _refresh();
  }

  void _refresh() {
    _ref.invalidate(patrimoineListProvider);
    _ref.invalidate(patrimoineTotalValueProvider);
  }
}
