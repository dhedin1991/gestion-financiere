import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';

class RecurringTransactionDao {
  final AppDatabase _appDatabase;
  RecurringTransactionDao(this._appDatabase);

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.insert('recurring_transactions', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> update(int id, Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    await db.update('recurring_transactions', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _appDatabase.database;
    await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> findAll() async {
    final db = await _appDatabase.database;
    return db.query('recurring_transactions', orderBy: 'next_due_date ASC');
  }

  Future<List<Map<String, dynamic>>> findDue({required String todayIso}) async {
    final db = await _appDatabase.database;
    return db.query(
      'recurring_transactions',
      where: 'active = 1 AND next_due_date <= ?',
      whereArgs: [todayIso],
    );
  }
}
