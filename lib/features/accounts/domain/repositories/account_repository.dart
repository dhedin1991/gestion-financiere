import '../entities/account.dart';

/// Contrat abstrait que la couche Data devra respecter.
///
/// Le Domain (et donc, indirectement, la Presentation) ne dépend QUE
/// de cette interface — jamais de l'implémentation concrète SQLite.
/// C'est ce qui permettra, plus tard, de brancher une source Cloud
/// sans rien changer ici.
abstract class AccountRepository {
  Future<List<Account>> getAllAccounts({bool includeArchived = false});
  Future<Account?> getAccountById(int id);
  Future<double> getGlobalBalance();
  Future<Account> createAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> deleteAccount(int id);
  Future<void> archiveAccount(int id);
  Future<void> unarchiveAccount(int id);
  Future<List<Account>> getArchivedAccounts();
  Future<bool> hasLinkedData(int id);
}
