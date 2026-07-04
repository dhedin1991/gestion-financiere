import '../../../../core/database/app_database.dart';

/// DAO Épargne.
///
/// Point important : chaque versement/retrait doit mettre à jour à la fois
/// `savings.current_balance` ET `accounts.current_balance` du compte lié.
/// On utilise `db.transaction()` pour garantir que les trois écritures
/// (mouvement + solde épargne + solde compte) se font ensemble ou pas
/// du tout (atomicité), exactement comme pour le module Transactions.
class SavingsDao {
  final AppDatabase _appDatabase;
  SavingsDao(this._appDatabase);

  Future<List<Map<String, dynamic>>> findAll() async {
    final db = await _appDatabase.database;
    return db.query('savings', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> findById(int id) async {
    final db = await _appDatabase.database;
    final rows = await db.query('savings', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.insert('savings', data);
  }

  Future<void> update(int id, Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    await db.update('savings', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _appDatabase.database;
    await db.delete('savings', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> findTransactionsBySavings(int savingsId) async {
    final db = await _appDatabase.database;
    return db.query(
      'savings_transactions',
      where: 'savings_id = ?',
      whereArgs: [savingsId],
      orderBy: 'date DESC, id DESC',
    );
  }

  /// Enregistre un versement ou un retrait ET répercute l'effet sur :
  /// - le solde de l'épargne (savings.current_balance)
  /// - le solde du compte lié (accounts.current_balance)
  /// signedAmount est positif pour un versement, négatif pour un retrait.
  /// Pour le compte, l'effet est inversé : un versement retire de l'argent
  /// du compte (donc -signedAmount côté compte), un retrait lui en rend.
  Future<int> insertTransactionWithBalanceUpdate({
    required Map<String, dynamic> data,
    required int savingsId,
    required int accountId,
    required double signedAmount,
  }) async {
    final db = await _appDatabase.database;
    final nowIso = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final id = await txn.insert('savings_transactions', data);

      // Le solde de l'épargne évolue dans le même sens que le mouvement.
      await txn.rawUpdate(
        'UPDATE savings SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
        [signedAmount, nowIso, savingsId],
      );

      // Le solde du compte évolue en sens inverse (un versement sort de l'argent du compte).
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
        [signedAmount, nowIso, accountId],
      );

      return id;
    });
  }

  /// Supprime un mouvement ET annule son effet sur les deux soldes.
  Future<void> deleteTransactionWithBalanceUpdate({
    required int transactionId,
    required int savingsId,
    required int accountId,
    required double signedAmount,
  }) async {
    final db = await _appDatabase.database;
    final nowIso = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('savings_transactions', where: 'id = ?', whereArgs: [transactionId]);

      await txn.rawUpdate(
        'UPDATE savings SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
        [signedAmount, nowIso, savingsId],
      );

      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
        [signedAmount, nowIso, accountId],
      );
    });
  }
}
