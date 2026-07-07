import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_dao.dart';
import '../models/account_model.dart';

/// Implémentation concrète de AccountRepository.
///
/// C'est ICI, et uniquement ici, que le Domain "rencontre" SQLite —
/// via le DAO. Le reste de l'app (UseCases, Widgets) ne le sait jamais.
class AccountRepositoryImpl implements AccountRepository {
  final AccountDao _dao;

  AccountRepositoryImpl(this._dao);

  @override
  Future<List<Account>> getAllAccounts({bool includeArchived = false}) async {
    final rows = await _dao.findAll(includeArchived: includeArchived);
    return rows.map(AccountModel.fromMap).toList();
  }

  @override
  Future<Account?> getAccountById(int id) async {
    final row = await _dao.findById(id);
    return row == null ? null : AccountModel.fromMap(row);
  }

  @override
  Future<double> getGlobalBalance() {
    return _dao.sumCurrentBalances();
  }

  @override
  Future<Account> createAccount(Account account) async {
    final now = DateTime.now();
    final toCreate = account.copyWith(
      currentBalance: account.initialBalance,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _dao.insert(AccountModel.toMap(toCreate));
    return toCreate.copyWith(id: id);
  }

  @override
  Future<void> updateAccount(Account account) async {
    if (account.id == null) {
      throw ArgumentError('Impossible de mettre à jour un compte sans id');
    }
    final updated = account.copyWith(updatedAt: DateTime.now());
    await _dao.update(account.id!, AccountModel.toMap(updated));
  }

  @override
  Future<void> deleteAccount(int id) {
    return _dao.delete(id);
  }

  @override
  Future<void> archiveAccount(int id) {
    return _dao.archive(id);
  }

  @override
  Future<void> unarchiveAccount(int id) {
    return _dao.unarchive(id);
  }

  @override
  Future<List<Account>> getArchivedAccounts() async {
    final rows = await _dao.findArchived();
    return rows.map(AccountModel.fromMap).toList();
  }

  @override
  Future<bool> hasLinkedData(int id) {
    return _dao.hasLinkedData(id);
  }
}
