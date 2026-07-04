import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';

/// Data Access Object : seule classe autorisée à écrire du SQL brut
/// pour les tables `debts` et `debt_payments`.
class DebtDao {
  final AppDatabase _appDatabase;

  DebtDao(this._appDatabase);

  Future<List<Map<String, dynamic>>> findAll() async {
    final db = await _appDatabase.database;
    return db.query('debts', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> findById(int id) async {
    final db = await _appDatabase.database;
    final results = await db.query('debts', where: 'id = ?', whereArgs: [id], limit: 1);
    return results.isEmpty ? null : results.first;
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.insert('debts', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.update('debts', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  /// Somme des paiements déjà effectués pour une dette donnée.
  Future<double> sumPaymentsForDebt(int debtId) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM debt_payments WHERE debt_id = ?',
      [debtId],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> findPaymentsByDebt(int debtId) async {
    final db = await _appDatabase.database;
    return db.query(
      'debt_payments',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'payment_date DESC',
    );
  }

  Future<int> insertPayment(Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.insert('debt_payments', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> deletePayment(int id) async {
    final db = await _appDatabase.database;
    return db.delete('debt_payments', where: 'id = ?', whereArgs: [id]);
  }
}
