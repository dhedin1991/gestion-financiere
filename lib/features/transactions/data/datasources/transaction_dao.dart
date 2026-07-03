import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';

/// DAO Transactions.
///
/// Point important : chaque écriture (création/modification/suppression)
/// doit AUSSI mettre à jour `accounts.current_balance` pour rester cohérent.
/// On utilise `db.transaction()` (transaction SQL, à ne pas confondre avec
/// l'entité métier "Transaction") pour garantir qu'aucune des deux écritures
/// ne se fasse sans l'autre (atomicité).
class TransactionDao {
  final AppDatabase _appDatabase;
  TransactionDao(this._appDatabase);

  Future<List<Map<String, dynamic>>> find({
    int? accountId,
    String? type,
    String? fromIso,
    String? toIso,
    int limit = 100,
  }) async {
    final db = await _appDatabase.database;

    final conditions = <String>[];
    final args = <Object?>[];

    if (accountId != null) {
      conditions.add('account_id = ?');
      args.add(accountId);
    }
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }
    if (fromIso != null) {
      conditions.add('transaction_date >= ?');
      args.add(fromIso);
    }
    if (toIso != null) {
      conditions.add('transaction_date <= ?');
      args.add(toIso);
    }

    return db.query(
      'transactions',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: conditions.isEmpty ? null : args,
      orderBy: 'transaction_date DESC, id DESC',
      limit: limit,
    );
  }

  Future<double> sumByType(String type, {String? fromIso, String? toIso}) async {
    final db = await _appDatabase.database;
    final conditions = <String>['type = ?'];
    final args = <Object?>[type];
    if (fromIso != null) {
      conditions.add('transaction_date >= ?');
      args.add(fromIso);
    }
    if (toIso != null) {
      conditions.add('transaction_date <= ?');
      args.add(toIso);
    }
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE ${conditions.join(' AND ')}',
      args,
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Crée une transaction ET applique son effet sur le solde du compte,
  /// dans une seule transaction SQL atomique.
  Future<int> insertWithBalanceUpdate(Map<String, dynamic> data, double signedAmount) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final id = await txn.insert('transactions', data);
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
        [signedAmount, DateTime.now().toIso8601String(), data['account_id']],
      );
      return id;
    });
  }

  /// Supprime une transaction ET annule son effet sur le solde du compte.
  Future<void> deleteWithBalanceUpdate(int id, int accountId, double signedAmount) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
        [signedAmount, DateTime.now().toIso8601String(), accountId],
      );
    });
  }

  /// Modifie une transaction : annule l'ancien effet, applique le nouveau.
  /// (Les deux comptes concernés peuvent être différents si l'utilisateur
  /// change le compte de la transaction.)
  Future<void> updateWithBalanceUpdate({
    required int id,
    required Map<String, dynamic> newData,
    required int oldAccountId,
    required double oldSignedAmount,
    required int newAccountId,
    required double newSignedAmount,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.update('transactions', newData, where: 'id = ?', whereArgs: [id]);

      // Annule l'ancien effet sur l'ancien compte.
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
        [oldSignedAmount, DateTime.now().toIso8601String(), oldAccountId],
      );
      // Applique le nouvel effet sur le nouveau compte.
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
        [newSignedAmount, DateTime.now().toIso8601String(), newAccountId],
      );
    });
  }

  Future<Map<String, dynamic>?> findById(int id) async {
    final db = await _appDatabase.database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }
}
