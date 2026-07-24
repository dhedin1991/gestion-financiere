import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';

/// Data Access Object : seule classe autorisée à écrire du SQL brut
/// pour la table `accounts`. Le reste de l'application ne voit jamais
/// de requête SQL directement.
class AccountDao {
  final AppDatabase _appDatabase;

  AccountDao(this._appDatabase);

  Future<List<Map<String, dynamic>>> findAll({bool includeArchived = false, int? entityId}) async {
    final db = await _appDatabase.database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (!includeArchived) {
      conditions.add('is_archived = ?');
      args.add(0);
    }
    if (entityId != null) {
      conditions.add('entity_id = ?');
      args.add(entityId);
    }
    return db.query(
      'accounts',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: conditions.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> findById(int id) async {
    final db = await _appDatabase.database;
    final results = await db.query('accounts', where: 'id = ?', whereArgs: [id], limit: 1);
    return results.isEmpty ? null : results.first;
  }

  Future<double> sumCurrentBalances() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(current_balance), 0) as total FROM accounts WHERE is_archived = 0',
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.insert('accounts', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.update('accounts', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> archive(int id) async {
    final db = await _appDatabase.database;
    return db.update(
      'accounts',
      {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> unarchive(int id) async {
    final db = await _appDatabase.database;
    return db.update(
      'accounts',
      {'is_archived': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> findArchived() async {
    final db = await _appDatabase.database;
    return db.query(
      'accounts',
      where: 'is_archived = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
  }

  Future<bool> hasLinkedData(int id) async {
    final db = await _appDatabase.database;

    final transactions = await db.query(
      'transactions',
      where: 'account_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (transactions.isNotEmpty) return true;

    final debts = await db.query(
      'debts',
      where: 'account_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (debts.isNotEmpty) return true;

    final savings = await db.query(
      'savings',
      where: 'account_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (savings.isNotEmpty) return true;

    final credits = await db.query(
      'credits',
      where: 'account_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (credits.isNotEmpty) return true;

    return false;
  }
}
