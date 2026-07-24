import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../entities/presentation/providers/entity_providers.dart';
import '../../data/datasources/account_dao.dart';
import '../../data/repositories/account_repository_impl.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';

// ---------------------------------------------------------------------
// Chaîne d'injection de dépendances : Database -> DAO -> Repository
// Chaque provider ne dépend que du précédent, jamais de la base
// directement — respecte la règle de dépendance de Clean Architecture.
// ---------------------------------------------------------------------

final accountDaoProvider = Provider<AccountDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AccountDao(db);
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final dao = ref.watch(accountDaoProvider);
  return AccountRepositoryImpl(dao);
});

/// Liste des comptes actifs (non archivés), rafraîchie automatiquement
/// après toute création/modification/suppression via `ref.invalidate`.
final accountsListProvider = FutureProvider.autoDispose<List<Account>>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  final entityId = ref.watch(currentEntityIdProvider);
  return repository.getAllAccounts(entityId: entityId);
});

/// Solde global (somme de tous les comptes) — utilisé par le Dashboard.
final globalBalanceProvider = FutureProvider.autoDispose<double>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getGlobalBalance();
});

/// Liste des comptes archivés — utilisée par la page Archives.
final archivedAccountsListProvider = FutureProvider.autoDispose<List<Account>>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getArchivedAccounts();
});

/// Liste de TOUS les comptes, y compris archivés. Utilisée uniquement dans
/// les formulaires de modification (transactions, dettes, épargne, crédits)
/// pour éviter un plantage du menu déroulant quand l'enregistrement en
/// cours de modification est lié à un compte qui a été archivé depuis.
final allAccountsIncludingArchivedProvider = FutureProvider.autoDispose<List<Account>>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getAllAccounts(includeArchived: true);
});

/// Contrôleur exposant les actions (créer/modifier/supprimer un compte).
/// Sépare volontairement les "commandes" (ce provider) des "lectures"
/// (accountsListProvider) — plus simple à tester et à maintenir.
final accountActionsProvider = Provider<AccountActions>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return AccountActions(ref, repository);
});

class AccountActions {
  final Ref _ref;
  final AccountRepository _repository;

  AccountActions(this._ref, this._repository);

  Future<void> create(Account account) async {
    final entityId = account.entityId ?? _ref.read(currentEntityIdProvider);
    await _repository.createAccount(account.copyWith(entityId: entityId));
    _refresh();
  }

  Future<void> update(Account account) async {
    await _repository.updateAccount(account);
    _refresh();
  }

  Future<void> delete(int id) async {
    await _repository.deleteAccount(id);
    _refresh();
  }

  Future<void> archive(int id) async {
    await _repository.archiveAccount(id);
    _refresh();
  }

  Future<void> unarchive(int id) async {
    await _repository.unarchiveAccount(id);
    _refresh();
  }

  void _refresh() {
    // Invalide les providers de lecture pour que l'UI se remette à jour
    // automatiquement après une action d'écriture.
    _ref.invalidate(accountsListProvider);
    _ref.invalidate(globalBalanceProvider);
    _ref.invalidate(archivedAccountsListProvider);
    _ref.invalidate(allAccountsIncludingArchivedProvider);
  }
}
